# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module Session
        class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, auth_context:)
            response_effects = {
              set_expire_header: auth_context.token_expires_at
            }

            if auth_context.generated_token.present?
              response_effects[:set_token] = {
                token: auth_context.generated_token,
                expires_at: auth_context.token_expires_at
              }
              response_effects[:ensure_csrf_cookie] = { rotate: csrf_rotate_on_reset? }
            end

            success(
              payload: CommandTower::Serializers::Auth::SessionResponseSerializer.serialize(
                user: current_user,
                token_expires_at: auth_context.token_expires_at
              ),
              http_status: :ok,
              response_effects: response_effects
            )
          end

          private

          def csrf_rotate_on_reset?
            return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?

            CommandTower.config.jwt.cookie.csrf.rotate_on_reset
          end
        end
      end
    end
  end
end
