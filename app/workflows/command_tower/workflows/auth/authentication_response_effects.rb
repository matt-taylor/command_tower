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
          if metadata[:cookie_authenticated] && metadata[:authentication_failed]
            effects[:clear_auth_cookie] = true
          end
          effects
        end
      end
    end
  end
end
