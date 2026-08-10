# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class VerificationCodeInvalidError < CommandTower::Errors::ValidationError
        def code
          "verification_code_invalid"
        end

        def message
          "Verification code is invalid"
        end
      end
    end
  end
end
