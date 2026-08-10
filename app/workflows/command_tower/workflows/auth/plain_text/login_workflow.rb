# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PlainText
        class LoginWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(input:, request_context: nil)
            login_result = CommandTower::Services::Auth::PlainText::Login.call(
              identifier: input.identifier,
              password: input.password
            )

            if login_result.success?
              data = login_result.data
              return success(
                payload: CommandTower::Serializers::Auth::LoginResponseSerializer.serialize(
                  user: data[:user],
                  token: data[:token],
                  token_expires_at: data[:expires_at]
                ),
                http_status: :created,
                response_effects: {
                  set_token: { token: data[:token], expires_at: data[:expires_at] },
                  ensure_csrf_cookie: { rotate: csrf_rotate_on_login? }
                }
              )
            end

            failure(errors: login_result.errors, http_status: :unauthorized)
          end

          private

          def csrf_rotate_on_login?
            return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?

            CommandTower.config.jwt.cookie.csrf.rotate_on_login
          end
        end
      end
    end
  end
end
