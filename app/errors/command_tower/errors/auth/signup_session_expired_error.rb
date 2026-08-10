# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SignupSessionExpiredError < CommandTower::Errors::UnauthorizedError
        def code
          "signup_session_expired"
        end

        def message
          "Signup session token has expired"
        end
      end
    end
  end
end
