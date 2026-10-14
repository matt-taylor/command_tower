# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Provider-neutral Expo push rendered payload. recipient_address is the opaque
      # first eligible endpoint id for the ChannelRenderer gate — never the Expo token.
      # Fan-out uses AdapterRequest#eligible_endpoint_ids.
      #
      # `sound` is the host sound asset file name, or nil for System Default. `urgency` is
      # the member's effective urgency level. `thread_id` is the conversation key, or nil
      # for a standalone message. `badge` is the absolute badge-eligible unread count, or
      # nil when the type is not badge-eligible. The provider adapter maps them to its
      # own fields. A badge of 0 is a real count.
      RenderedPushPayload = Data.define(
        :recipient_address,
        :title,
        :body,
        :deep_link,
        :sound,
        :urgency,
        :thread_id,
        :badge,
      ) do
        def self.build(
          recipient_address:,
          title:,
          body:,
          deep_link: nil,
          sound: nil,
          urgency: "normal",
          thread_id: nil,
          badge: nil
        )
          values = [recipient_address, title, body, deep_link, sound, urgency, thread_id, badge]
          raise ArgumentError, "arbitrary hashes are not accepted" if values.any? { |v| v.is_a?(Hash) }
          raise ArgumentError, "ActiveRecord objects are not accepted" if values.any? { |v| active_record_like?(v) }
          raise ArgumentError, "raw exception objects are not accepted" if values.any? { |v| v.is_a?(Exception) }

          validate_required_string!(recipient_address, "recipient_address")
          validate_required_string!(title, "title")
          validate_required_string!(body, "body")
          validate_optional_string!(deep_link, "deep_link")
          validate_optional_string!(sound, "sound")
          validate_urgency!(urgency)
          validate_optional_string!(thread_id, "thread_id")
          validate_badge!(badge)
          raise ArgumentError, "thread_id must be at most 128 characters" if thread_id && thread_id.length > 128

          new(
            recipient_address:,
            title:,
            body:,
            deep_link:,
            sound:,
            urgency:,
            thread_id:,
            badge:,
          ).freeze
        end

        def self.validate_required_string!(value, field_name)
          raise ArgumentError, "#{field_name} is required" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          raise ArgumentError, "#{field_name} must be a String" unless value.is_a?(String)
        end
        private_class_method :validate_required_string!

        def self.validate_optional_string!(value, field_name)
          return if value.nil?

          raise ArgumentError, "#{field_name} must be a String" unless value.is_a?(String)
          raise ArgumentError, "#{field_name} must not be blank when present" if value.strip.empty?
        end
        private_class_method :validate_optional_string!

        def self.validate_urgency!(urgency)
          return if NotificationTypes::URGENCY_LEVELS.include?(urgency)

          raise ArgumentError, "urgency must be one of #{NotificationTypes::URGENCY_LEVELS.join(', ')}"
        end
        private_class_method :validate_urgency!

        def self.validate_badge!(badge)
          return if badge.nil?
          return if badge.is_a?(Integer) && badge >= 0

          raise ArgumentError, "badge must be a nonnegative integer"
        end
        private_class_method :validate_badge!

        def self.active_record_like?(value)
          defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
        end
        private_class_method :active_record_like?
      end
    end
  end
end
