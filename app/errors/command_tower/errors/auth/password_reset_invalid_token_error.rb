# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordResetInvalidTokenError < CommandTower::Errors::ApplicationError
        def code
          "password_reset_invalid_token"
        end

        def message
          "Invalid token"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
