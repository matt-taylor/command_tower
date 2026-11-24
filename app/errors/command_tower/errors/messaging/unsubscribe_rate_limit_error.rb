# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      class UnsubscribeRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "unsubscribe_rate_limited"
        end

        def message
          "Too many unsubscribe requests"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
