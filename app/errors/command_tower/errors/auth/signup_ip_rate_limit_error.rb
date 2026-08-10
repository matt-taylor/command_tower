# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SignupIpRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "signup_ip_rate_limited"
        end

        def message
          "Too many signup requests from this network"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
