# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class RegisterResponseSerializer
        def self.serialize(user:)
          {
            user: UserSerializer.serialize(user),
            message: "Account created successfully"
          }
        end
      end
    end
  end
end
