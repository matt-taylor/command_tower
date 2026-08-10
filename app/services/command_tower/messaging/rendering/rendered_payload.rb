# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      RenderedPayload = Data.define(
        :recipient_address,
        :subject,
        :text_body,
        :html_body,
      ) do
        def self.build(recipient_address:, subject:, text_body:, html_body:)
          values = [recipient_address, subject, text_body, html_body]
          raise ArgumentError, "arbitrary hashes are not accepted" if values.any? { |v| v.is_a?(Hash) }
          raise ArgumentError, "ActiveRecord objects are not accepted" if values.any? { |v| active_record_like?(v) }
          raise ArgumentError, "raw exception objects are not accepted" if values.any? { |v| v.is_a?(Exception) }

          validate_required_string!(recipient_address, "recipient_address")
          validate_required_string!(subject, "subject")
          validate_required_string!(text_body, "text_body")
          validate_required_string!(html_body, "html_body")

          new(
            recipient_address:,
            subject:,
            text_body:,
            html_body:,
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
