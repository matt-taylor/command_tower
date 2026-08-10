# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SignupSessionInvalidError < CommandTower::Errors::UnauthorizedError
        def code
          "signup_session_invalid"
        end

        def message
          "Signup session token is invalid"
        end
      end
    end
  end
end
