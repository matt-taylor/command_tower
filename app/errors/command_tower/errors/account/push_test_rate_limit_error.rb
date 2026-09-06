# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushTestRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "push_test_rate_limited"
        end

        def message
          "Too many push test notifications. Please try again later."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
