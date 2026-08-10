# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordResetUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "password_reset_unavailable"
        end

        def message
          "Password reset is currently unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
