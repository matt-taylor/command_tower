# frozen_string_literal: true

module CommandTower
  module Serializers
    module Application
      class ErrorEntrySerializer
        def self.serialize(error)
          entry = {
            code: error.code,
            message: error.message
          }
          entry[:details] = error.details if error.details.present?
          entry
        end
      end
    end
  end
end
