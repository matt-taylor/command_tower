# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneVerificationCodeInvalidError < CommandTower::Errors::ApplicationError
        def code
          "phone_verification_code_invalid"
        end

        def message
          "Incorrect verification code"
        end
      end
    end
  end
end
