# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class VerificationSendFailedError < CommandTower::Errors::ApplicationError
        def code
          "verification_send_failed"
        end

        def message
          "Unable to send verification email"
        end

        def retryable?
          true
        end

        def log_level
          :error
        end
      end
    end
  end
end
