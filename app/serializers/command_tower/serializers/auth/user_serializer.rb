# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class UserSerializer
        def self.serialize(user)
          {
            id: user.id,
            email: user.email,
            username: user.username,
            firstName: user.first_name,
            lastName: user.last_name,
            emailValidated: user.email_validated,
            roles: user.roles
          }
        end
      end
    end
  end
end
