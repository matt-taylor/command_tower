# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PlainText
        class LoginWorkflow < CommandTower::Workflows::ApplicationWorkflow
          include CommandTower::Workflows::ClientCompatibility::RecommendationMeta

          retry_strategy :none

          def call(input:, request_context: nil, client_ip: nil)
            login_result = CommandTower::Services::Auth::PlainText::Login.call(
              identifier: input.identifier,
              password: input.password,
              client_ip: client_ip
            )

            if login_result.success?
              data = login_result.data
              CommandTower::Execution::IdentityEnrichment.from_user(data[:user])
              audit(:session_created, affected_user: data[:user], changes: {})
              return success(
                payload: CommandTower::Serializers::Auth::LoginResponseSerializer.serialize(
                  user: data[:user],
                  token: data[:token],
                  token_expires_at: data[:expires_at]
                ),
                http_status: :created,
                meta: client_compatibility_meta,
                response_effects: {
                  set_token: CommandTower::Workflows::Auth::AuthenticationResponseEffects.for_set_token(
                    token: data[:token],
                    expires_at: data[:expires_at],
                    device_session: data[:device_session]
                  ),
                  ensure_csrf_cookie: { rotate: csrf_rotate_on_login? }
                }
              )
            end

            failure(errors: login_result.errors, http_status: failure_http_status(login_result.errors.first))
          end

          private

          # Every login failure stays 401 except a rate limit, which is 429.
          def failure_http_status(error)
            return :unauthorized unless error.is_a?(CommandTower::Errors::Auth::AuthRateLimitedError)

            CommandTower::Workflows::Auth::SessionErrorStatus.http_status_for(error)
          end

          def csrf_rotate_on_login?
            return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?

            CommandTower.config.jwt.cookie.csrf.rotate_on_login
          end
        end
      end
    end
  end
end
