# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class EmailAvailabilitySerializer
        def self.serialize(valid:, available:, message:)
          {
            valid: valid,
            available: available,
            message: message
          }
        end
      end
    end
  end
end
