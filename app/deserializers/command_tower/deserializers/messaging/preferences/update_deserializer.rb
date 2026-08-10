# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Messaging
      module Preferences
        class UpdateDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:notification_type_key, :preference_state)

          ROUTING_KEYS = %w[controller action format notification_type_key preference].freeze
          ALLOWED_PREFERENCE_KEYS = %w[inboxEnabled channels].freeze

          def call(params)
            raw = normalize_hash(params)
            return failure(errors: { message: "invalid_notification_type_key" }) if raw.nil?

            notification_type_key = raw["notification_type_key"]
            if notification_type_key.nil? || !notification_type_key.is_a?(String) || notification_type_key.strip.empty?
              return failure(errors: { message: "invalid_notification_type_key" })
            end

            extras = raw.keys - ROUTING_KEYS - ["preferences"]
            return failure(errors: { message: "unexpected_fields" }) if extras.any?
            return failure(errors: { message: "missing_preferences" }) unless raw.key?("preferences")

            preferences = raw["preferences"]
            return failure(errors: { message: "invalid_preferences" }) unless preferences.is_a?(Hash)

            preference_state = parse_preferences(preferences)
            return preference_state if preference_state.is_a?(DeserializerResult)

            success(
              Input.new(
                notification_type_key: notification_type_key.strip,
                preference_state:,
              ),
            )
          end

          private

          def normalize_hash(params)
            hash =
              if params.respond_to?(:to_unsafe_h)
                params.to_unsafe_h
              elsif params.respond_to?(:to_h)
                params.to_h
              else
                return nil
              end

            hash.each_with_object({}) do |(key, value), result|
              result[key.to_s] =
                if value.respond_to?(:to_unsafe_h)
                  value.to_unsafe_h.transform_keys(&:to_s)
                elsif value.is_a?(Hash)
                  value.transform_keys(&:to_s)
                else
                  value
                end
            end
          end

          def parse_preferences(preferences)
            unknown = preferences.keys - ALLOWED_PREFERENCE_KEYS
            return failure(errors: { message: "unexpected_preference_fields" }) if unknown.any?

            state = {}

            if preferences.key?("channels")
              channels = preferences["channels"]
              return failure(errors: { message: "invalid_channels" }) unless channels.is_a?(Hash)

              parsed_channels = {}
              channels.each do |channel_key, channel_value|
                return failure(errors: { message: "invalid_channel_key" }) unless channel_key.is_a?(String) || channel_key.is_a?(Symbol)
                return failure(errors: { message: "invalid_channel_value" }) unless [true, false].include?(channel_value)

                parsed_channels[channel_key.to_s] = channel_value
              end
              state["channels"] = parsed_channels
            end

            if preferences.key?("inboxEnabled")
              inbox = preferences["inboxEnabled"]
              return failure(errors: { message: "invalid_inbox_enabled" }) unless [true, false].include?(inbox)

              state["inbox"] = inbox
            end

            state
          end
        end
      end
    end
  end
end
