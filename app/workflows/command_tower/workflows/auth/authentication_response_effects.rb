# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # Translates authentication observation metadata into transport effects the
      # renderer applies. Keeps cookie mechanics out of the authentication service.
      module AuthenticationResponseEffects
        module_function

        # Token-issuing effect. `expires_at` is the sliding signal (X-Authorization-Expire);
        # the cookie lives to the device session's absolute expiry when one exists.
        def for_set_token(token:, expires_at:, device_session: nil, header: true)
          {
            token: token,
            expires_at: expires_at,
            header: header,
            cookie_expires_at: device_session&.absolute_expires_at
          }
        end

        def for_auth_failure(metadata)
          effects = {}
          # 412 email verification is a live session that still needs the JWT
          # cookie so the client can send/verify the code.
          if metadata[:cookie_authenticated] && metadata[:authentication_failed] &&
              !metadata[:email_verification_required] &&
              !metadata[:impersonation_session_expired]
            effects[:clear_auth_cookie] = true
          end
          effects
        end
      end
    end
  end
end
