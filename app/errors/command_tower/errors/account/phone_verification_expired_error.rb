# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneVerificationExpiredError < CommandTower::Errors::ApplicationError
        def code
          "phone_verification_code_expired"
        end

        def message
          "Verification code has expired"
        end
      end
    end
  end
end
