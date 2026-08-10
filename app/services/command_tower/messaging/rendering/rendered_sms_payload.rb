# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Provider-neutral SMS rendered payload. Recipient is resolved separately at
      # execution and included here for the adapter request contract (same as email).
      RenderedSmsPayload = Data.define(
        :recipient_address,
        :body,
      ) do
        def self.build(recipient_address:, body:)
          values = [recipient_address, body]
          raise ArgumentError, "arbitrary hashes are not accepted" if values.any? { |v| v.is_a?(Hash) }
          raise ArgumentError, "ActiveRecord objects are not accepted" if values.any? { |v| active_record_like?(v) }
          raise ArgumentError, "raw exception objects are not accepted" if values.any? { |v| v.is_a?(Exception) }

          validate_required_string!(recipient_address, "recipient_address")
          validate_required_string!(body, "body")

          new(
            recipient_address:,
            body:,
          ).freeze
        end

        def self.validate_required_string!(value, field_name)
          raise ArgumentError, "#{field_name} is required" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          raise ArgumentError, "#{field_name} must be a String" unless value.is_a?(String)
        end
        private_class_method :validate_required_string!

        def self.active_record_like?(value)
          defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
        end
        private_class_method :active_record_like?
      end
    end
  end
end
