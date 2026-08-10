# frozen_string_literal: true

module CommandTower
  module Serializers
    module Application
      class EnvelopeSerializer
        def self.success(data:, meta: {})
          {
            data: data,
            meta: meta,
            errors: []
          }
        end

        def self.failure(errors:, meta: {})
          {
            data: nil,
            meta: meta,
            errors: errors
          }
        end
      end
    end
  end
end
