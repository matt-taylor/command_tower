# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # Translates authentication observation metadata into transport effects the
      # renderer applies. Keeps cookie mechanics out of the authentication service.
      module AuthenticationResponseEffects
        module_function

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
