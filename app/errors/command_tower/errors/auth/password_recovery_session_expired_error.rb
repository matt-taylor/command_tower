# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordRecoverySessionExpiredError < CommandTower::Errors::ApplicationError
        def code
          "password_recovery_session_expired"
        end

        def message
          "Password recovery session has expired"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
