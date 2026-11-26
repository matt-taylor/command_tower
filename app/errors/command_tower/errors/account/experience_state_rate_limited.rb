# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class ExperienceStateRateLimited < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "experience_state_rate_limited"
        end

        def message
          "Too many requests. Please try again later."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
