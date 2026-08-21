# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class AuthenticateRequestWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(request:, response:, bypass_email_validation: false, overlay_mode: :enforce)
          request_context = CommandTower::Auth::RequestContext.from(request, response)
          auth_result = CommandTower::Services::Auth::AuthenticateSession.call(
            request_context: request_context,
            bypass_email_validation: bypass_email_validation,
            overlay_mode: overlay_mode
          )

          unless auth_result.success?
            return failure(
              errors: auth_result.errors,
              http_status: SessionErrorStatus.http_status_for(auth_result.errors.first),
              response_effects: AuthenticationResponseEffects.for_auth_failure(auth_result.metadata).presence
            )
          end

          auth_context = CommandTower::Auth::AuthContext.from_authenticate_session_result(
            data: auth_result.data,
            metadata: auth_result.metadata
          )

          success(
            payload: {
              current_user: auth_context.user,
              auth_context: auth_context
            },
            http_status: :ok
          )
        end
      end
    end
  end
end
