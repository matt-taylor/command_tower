# frozen_string_literal: true

module CommandTower
  module Errors
    module HomeNotices
      class RateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after: retry_after_seconds } : nil)
        end

        def code
          "home_notices_rate_limited"
        end

        def message
          "Too many home notice requests"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
