# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordRecoverySessionRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "password_recovery_session_rate_limited"
        end

        def message
          "Password recovery session send limit exceeded"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
