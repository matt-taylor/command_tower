# frozen_string_literal: true

module CommandTower
  module Api
    # Preserves client-visible ValidationError details when ApplicationDeserializer
    # Array-wraps a single Hash failure payload.
    module DeserializerFailureDetails
      extend ActiveSupport::Concern

      private

      def deserializer_failure_details(deserialized)
        errors = Array(deserialized.errors)
        if errors.size == 1 && errors.first.is_a?(Hash)
          errors.first
        else
          { failures: errors }
        end
      end
    end
  end
end
