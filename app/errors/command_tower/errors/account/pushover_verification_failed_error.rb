# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushoverVerificationFailedError < CommandTower::Errors::ApplicationError
        def initialize(code: "pushover_verification_failed", message: "Pushover verification failed", details: nil, cause: nil)
          @code = code
          @message = message
          super(details:, cause:)
        end

        def code
          @code
        end

        def message
          @message
        end

        def log_level
          :info
        end
      end
    end
  end
end
