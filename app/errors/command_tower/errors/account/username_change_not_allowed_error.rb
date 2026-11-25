# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class UsernameChangeNotAllowedError < CommandTower::Errors::ForbiddenError
        def code
          "username_change_not_allowed"
        end

        def message
          "Username cannot be changed"
        end
      end
    end
  end
end
