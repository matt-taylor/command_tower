# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class RegisterWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(input:, client_ip:)
          rate_result = CommandTower::Services::Auth::SignupRateLimits::CheckRegister.call(client_ip: client_ip)
          unless rate_result.success?
            return failure(
              errors: rate_result.errors,
              http_status: SignupErrorStatus.http_status_for(rate_result.errors.first)
            )
          end

          register_result = CommandTower::Services::Auth::Register.call(
            first_name: input.first_name,
            last_name: input.last_name,
            username: input.username,
            email: input.email,
            password: input.password,
            password_confirmation: input.password_confirmation
          )

          unless register_result.success?
            return failure(
              errors: register_result.errors,
              http_status: SignupErrorStatus.http_status_for(register_result.errors.first)
            )
          end

          user = register_result.data[:user]
          emit_welcome(user)

          success(
            payload: CommandTower::Serializers::Auth::RegisterResponseSerializer.serialize(
              user: user
            ),
            http_status: :created
          )
        end

        private

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
            event: "messaging.welcome_produce_failed",
            user_id: user.id,
            error_class: error.class.name,
          }
          payload[:error_code] = error.code if error.respond_to?(:code)
          payload[:error_message] = error.message if error.respond_to?(:message)
          Rails.logger.error(payload.to_json)
        end
      end
    end
  end
end
