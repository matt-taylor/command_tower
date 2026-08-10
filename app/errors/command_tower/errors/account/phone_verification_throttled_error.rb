# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneVerificationThrottledError < CommandTower::Errors::ApplicationError
        attr_reader :resend_available_at

        def initialize(resend_available_at: nil)
          @resend_available_at = resend_available_at
          super()
        end

        def code
          "phone_verification_throttled"
        end

        def message
          "Please wait before requesting another code"
        end
      end
    end
  end
end
