# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class AuthenticateSession < CommandTower::Services::ApplicationService
        validate :request_context, is_a: CommandTower::Auth::RequestContext, required: true
        validate :bypass_email_validation, is_one: [true, false], default: false

        def call
          request = request_context.request
          token_data = CommandTower::Jwt::AuthorizationHelper.extract_token(request)

          if token_data[:error]
            return fail_authentication!(
              CommandTower::Errors::UnauthorizedError.new,
              token_source: nil
            )
          end

          token = token_data[:token]
          token_source = token_data[:source]

          if csrf_required?(request, token_source)
            csrf_validation = CommandTower::Jwt::CsrfHelper.validate(request)
            unless csrf_validation[:valid]
              fail_authentication!(
                csrf_error_for(csrf_validation[:message]),
                token_source: :cookie
              )
              return
            end
          end

          with_reset = CommandTower::Jwt::AuthorizationHelper.get_with_reset_flag(request) || false
          auth_result = CommandTower::Jwt::AuthenticateUser.call(
            token:,
            with_reset:,
            bypass_email_validation:
          )
          if auth_result.success?
            context.user = auth_result.user
            context.token_expires_at = auth_result.expires_at
            context.generated_token = auth_result.generated_token if with_reset
            context.service_metadata = observation_metadata(
              token_source:,
              authentication_failed: false,
              cookie_authenticated: token_source == :cookie
            )
            return
          end

          if auth_result.status == 412
            fail_authentication!(
              CommandTower::Errors::Auth::EmailVerificationRequiredError.new,
              token_source:
            )
            return
          end

          fail_authentication!(CommandTower::Errors::UnauthorizedError.new, token_source:)
        end

        private

        def fail_authentication!(error, token_source:)
          context.service_metadata = observation_metadata(
            token_source:,
            authentication_failed: true,
            cookie_authenticated: token_source == :cookie
          )
          context.fail!(application_error: error)
        end

        def observation_metadata(token_source:, authentication_failed:, cookie_authenticated: nil)
          {
            token_source:,
            authentication_mechanism: :jwt,
            authentication_failed:,
            cookie_authenticated: cookie_authenticated.nil? ? token_source == :cookie : cookie_authenticated
          }
        end

        def csrf_error_for(message)
          case message
          when "csrf_mismatch"
            CommandTower::Errors::Auth::CsrfMismatchError.new
          else
            CommandTower::Errors::Auth::CsrfMissingError.new
          end
        end

        # Enforcement lives here because token_source is only reliably known once
        # the token has been extracted.
        def csrf_required?(request, token_source)
          return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?
          return false unless token_source == :cookie
          return false if request.get? || request.head? || request.options?

          %w[POST PUT PATCH DELETE].include?(request.method)
        end
      end
    end
  end
end
