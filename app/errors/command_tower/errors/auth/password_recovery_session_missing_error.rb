# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordRecoverySessionMissingError < CommandTower::Errors::ApplicationError
        def code
          "password_recovery_session_missing"
        end

        def message
          "Password recovery session is required"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
