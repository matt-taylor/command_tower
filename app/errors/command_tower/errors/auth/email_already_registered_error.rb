# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class EmailAlreadyRegisteredError < CommandTower::Errors::ValidationError
        def code
          "email_already_registered"
        end

        def message
          "Email is already registered"
        end
      end
    end
  end
end
