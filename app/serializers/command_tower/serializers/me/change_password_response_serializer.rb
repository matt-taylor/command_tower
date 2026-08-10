# frozen_string_literal: true

module CommandTower
  module Serializers
    module Me
      class ChangePasswordResponseSerializer
        def self.serialize(message: "Password updated successfully.")
          { message: message }
        end
      end
    end
  end
end
