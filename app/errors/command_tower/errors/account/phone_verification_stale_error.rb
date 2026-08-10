# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneVerificationStaleError < CommandTower::Errors::ApplicationError
        def code
          "phone_verification_stale"
        end

        def message
          "Verification code is no longer valid for this phone"
        end
      end
    end
  end
end
