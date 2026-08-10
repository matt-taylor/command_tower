# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SignupSessionMissingError < CommandTower::Errors::UnauthorizedError
        def code
          "signup_session_missing"
        end

        def message
          "Signup session token is required"
        end
      end
    end
  end
end
