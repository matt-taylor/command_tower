# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PhoneMissingError < CommandTower::Errors::ApplicationError
        def code
          "phone_missing"
        end

        def message
          "Phone number is required"
        end
      end
    end
  end
end
