# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SignupSessionRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "signup_session_rate_limited"
        end

        def message
          "Signup session lookup limit exceeded"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
