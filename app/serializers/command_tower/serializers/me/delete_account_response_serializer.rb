# frozen_string_literal: true

module CommandTower
  module Serializers
    module Me
      class DeleteAccountResponseSerializer
        def self.serialize(message:)
          { message: message }
        end
      end
    end
  end
end
