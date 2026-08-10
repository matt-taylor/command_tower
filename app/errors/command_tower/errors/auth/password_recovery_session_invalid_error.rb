# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordRecoverySessionInvalidError < CommandTower::Errors::ApplicationError
        def code
          "password_recovery_session_invalid"
        end

        def message
          "Password recovery session is invalid"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
