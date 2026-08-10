# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneVerificationSendFailedError < CommandTower::Errors::ApplicationError
        def code
          "phone_verification_send_failed"
        end

        def message
          "Unable to send verification code"
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
