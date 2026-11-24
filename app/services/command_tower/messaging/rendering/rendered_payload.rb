# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      RenderedPayload = Data.define(
        :recipient_address,
        :subject,
        :text_body,
        :html_body,
        :headers,
      ) do
        # `headers` is optional (extra RFC 8058 mail headers, String => String) so direct callers
        # predating it keep working.
        def initialize(headers: {}.freeze, **attributes)
          unless headers.is_a?(Hash) && headers.all? { |k, v| k.is_a?(String) && v.is_a?(String) }
            raise ArgumentError, "headers must be a Hash of String to String"
          end

          super(headers: headers.dup.freeze, **attributes)
        end

        def self.build(recipient_address:, subject:, text_body:, html_body:, headers: {})
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
            headers:,
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
