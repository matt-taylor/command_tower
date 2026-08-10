# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneAlreadyVerifiedError < CommandTower::Errors::ApplicationError
        def code
          "phone_already_verified"
        end

        def message
          "Phone number is already verified"
        end
      end
    end
  end
end
