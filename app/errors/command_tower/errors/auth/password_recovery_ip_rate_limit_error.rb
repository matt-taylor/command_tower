# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class PasswordRecoveryIpRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "password_recovery_ip_rate_limited"
        end

        def message
          "Too many password recovery requests from this network"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
