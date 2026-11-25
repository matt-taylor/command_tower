# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class UsernameTakenError < CommandTower::Errors::ValidationError
        def initialize(cause: nil)
          super(details: { username: "has already been taken" }, cause: cause)
        end

        def code
          "username_taken"
        end

        def message
          "Username is already taken"
        end
      end
    end
  end
end
