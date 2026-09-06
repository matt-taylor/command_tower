# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Provider-neutral Expo push rendered payload. recipient_address is the opaque
      # first eligible endpoint id for the ChannelRenderer gate — never the Expo token.
      # Fan-out uses AdapterRequest#eligible_endpoint_ids.
      RenderedPushPayload = Data.define(
        :recipient_address,
        :title,
        :body,
        :deep_link,
      ) do
        def self.build(recipient_address:, title:, body:, deep_link: nil)
          values = [recipient_address, title, body, deep_link]
          raise ArgumentError, "arbitrary hashes are not accepted" if values.any? { |v| v.is_a?(Hash) }
          raise ArgumentError, "ActiveRecord objects are not accepted" if values.any? { |v| active_record_like?(v) }
          raise ArgumentError, "raw exception objects are not accepted" if values.any? { |v| v.is_a?(Exception) }

          validate_required_string!(recipient_address, "recipient_address")
          validate_required_string!(title, "title")
          validate_required_string!(body, "body")
          unless deep_link.nil?
            raise ArgumentError, "deep_link must be a String" unless deep_link.is_a?(String)
            raise ArgumentError, "deep_link must not be blank when present" if deep_link.strip.empty?
          end

          new(
            recipient_address:,
            title:,
            body:,
            deep_link:,
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
