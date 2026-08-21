# frozen_string_literal: true

module CommandTower
  module Workflows
    module Impersonation
      class StartWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(id:, actor:, scope_value: nil)
          if CommandTower::Current.impersonation_active
            return failure(
              errors: [CommandTower::Errors::Auth::NestedImpersonationError.new],
              http_status: :forbidden
            )
          end

          if actor.id == id
            return failure(
              errors: [CommandTower::Errors::Auth::SelfImpersonationError.new],
              http_status: :unprocessable_entity
            )
          end

          scope_result = CommandTower::Workflows::Admin::ScopeResolution.resolve(
            tool_id: "users",
            user: actor,
            scope_value:
          )
          return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

          shown = CommandTower::Services::Admin::Users::Show.call(
            id:,
            principal: actor,
            scope_context: scope_result
          )
          unless shown.success?
            return failure(
              errors: shown.errors,
              http_status: CommandTower::Workflows::Admin::Users::ErrorMapping.http_status_for(shown.errors.first)
            )
          end

          target = shown.data[:user]
          created = CommandTower::Services::Impersonation::Create.call(actor:, target:)
          unless created.success?
            return failure(
              errors: created.errors,
              http_status: :internal_server_error
            )
          end

          session = created.data[:session]
          audit_started(session:, target:, scope_context: scope_result)

          token = CommandTower::Jwt::LoginCreate.call(
            user: actor,
            impersonation_session_id: session.id
          ).token
          expires_at = CommandTower.config.jwt.ttl.from_now.to_time.to_s

          success(
            payload: CommandTower::Serializers::Impersonation::SessionSerializer.serialize(session),
            http_status: :created,
            response_effects: {
              set_token: { token:, expires_at: }
            }
          )
        end

        private

        def audit_started(session:, target:, scope_context:)
          scope_class, host_context = audit_scope_for(scope_context)
          audit(
            :impersonation_started,
            subject: target,
            affected_user: target,
            metadata: { impersonation_session_id: session.id },
            attribution_mode: :admin_direct,
            scope_class:,
            host_context:
          )
        end

        def audit_scope_for(scope_context)
          return [:global, nil] if scope_context.nil?
          return [:global, nil] unless CommandTower.config.admin_scope.registered?("users")

          type = CommandTower.config.admin_scope.fetch("users").host_context_type
          return [:global, nil] if type.to_s.strip.empty?

          [:host, { type:, identifier: scope_context.scope_value }]
        end
      end
    end
  end
end
