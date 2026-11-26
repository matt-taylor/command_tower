# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class RegisterWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(input:, client_ip:)
          limited = rate_limit_failure(input, client_ip)
          return limited if limited

          user = nil
          result = transaction do
            user = create_user!(input)
            session = start_session!(user) if input.start_session

            success(
              payload: RegisterSessionResponse.payload(user:, session:),
              http_status: :created,
              response_effects: RegisterSessionResponse.effects(session)
            )
          end

          emit_welcome(user) if result.success? && user.present?
          result
        end

        private

        # Per-IP bucket first, then the per-email bucket. Returns a failure result or nil.
        def rate_limit_failure(input, client_ip)
          rate_services = CommandTower::Services::Auth::SignupRateLimits
          ip_result = rate_services::CheckRegister.call(client_ip: client_ip)
          return failure_from(ip_result) unless ip_result.success?

          email_result = rate_services::CheckRegisterEmail.call(email: input.email)
          failure_from(email_result) unless email_result.success?
        end

        def failure_from(service_result, http_status: SignupErrorStatus.http_status_for(service_result.errors.first))
          failure(errors: service_result.errors, http_status:)
        end

        def create_user!(input)
          register_result = CommandTower::Services::Auth::Register.call(
            first_name: input.first_name,
            last_name: input.last_name,
            username: input.username,
            email: input.email,
            password: input.password,
            password_confirmation: input.password_confirmation
          )
          fail_transaction!(failure_from(register_result)) unless register_result.success?

          user = register_result.data[:user]
          audit(:user_registered, subject: user, affected_user: user, changes: {})
          assign_default_role!(user)
        end

        def assign_default_role!(user)
          roles_before = Array(user.roles)
          assign_result = CommandTower::Services::Auth::AssignDefaultMembershipRole.call(user: user)
          fail_transaction!(failure_from(assign_result, http_status: :unprocessable_entity)) if assign_result.failure?

          user = assign_result.data[:user]
          assigned_roles = Array(user.roles) - roles_before
          if assigned_roles.any?
            audit(
              :role_assigned,
              subject: user,
              affected_user: user,
              changes: { role: { from: nil, to: assigned_roles.first.to_s } }
            )
          end
          user
        end

        # Same sequence as login (device session, then a token carrying its sid).
        def start_session!(user)
          issued = CommandTower::Services::Auth::IssueSession.call(user: user)
          fail_transaction!(failure(errors: issued.errors, http_status: :internal_server_error)) if issued.failure?

          audit(:session_created, affected_user: user, changes: {})
          issued.data
        end

        # Synchronous Produce so InboxItem exists before HTTP 201.
        # Soft-fail: registration already committed the user.
        def emit_welcome(user)
          content = CommandTower.config.messaging.welcome_content.call
          return if content.blank?

          content = content.with_indifferent_access
          result = CommandTower::Services::Messaging::Communications::Produce.call(
            user:,
            notification_type_key: content.fetch(:notification_type_key),
            host_event_identity: "user_welcome/#{user.id}",
            title: content.fetch(:title),
            body: content.fetch(:body),
            metadata: content[:metadata],
            platform_enabled_channels: CommandTower::Services::Messaging::Preferences::PlatformEnabledChannels.call,
          )
          return if result.success?

          log_welcome_failure(user, result.errors.first)
        rescue StandardError => error
          log_welcome_failure(user, error)
        end

        def log_welcome_failure(user, error)
          payload = {
            user_id: user.id,
            error_class: error.class.name,
            log_level: :error
          }
          payload[:error_code] = error.code if error.respond_to?(:code)
          publish_event(category: :messaging, name: :welcome_produce_failed, payload:)
        end
      end
    end
  end
end
