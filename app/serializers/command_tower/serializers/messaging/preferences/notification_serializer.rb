# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Preferences
        class NotificationSerializer
          def self.serialize(notification)
            payload = {
              key: notification.key,
              label: notification.label,
              description: notification.description,
              order: notification.order,
              configurable: notification.configurable,
              mandatory: notification.mandatory,
              inboxAvailable: notification.inbox_available,
              allowedChannels: notification.allowed_channels,
              availableChannels: notification.available_channels,
              channelCatalog: serialize_channel_catalog(notification.channel_catalog),
              destinations: serialize_destinations(notification.destinations),
              urgency: notification.urgency,
              sound: notification.sound,
              preferences: {
                inboxEnabled: notification.inbox_enabled,
                channels: notification.channels,
                storedOverridePresent: notification.stored_override_present,
              },
            }

            corrections = serialize_corrections(notification.corrections)
            payload[:corrections] = corrections unless corrections.nil?

            payload
          end

          def self.serialize_channel_catalog(entries)
            Array(entries).map do |entry|
              {
                key: entry[:key],
                label: entry[:label],
                description: entry[:description],
                order: entry[:order],
                glyphKey: entry[:glyph_key],
              }
            end
          end
          private_class_method :serialize_channel_catalog

          def self.serialize_destinations(destinations)
            destinations.to_h.transform_values do |entry|
              serialize_destination_entry(entry)
            end
          end
          private_class_method :serialize_destinations

          def self.serialize_destination_entry(entry)
            hash =
              if entry.respond_to?(:to_h)
                entry.to_h
              else
                entry
              end

            {
              state: entry_value(hash, :state),
              effective: entry_value(hash, :effective),
              reasonCode: entry_value(hash, :reason_code) || entry_value(hash, :reasonCode),
              reason: entry_value(hash, :reason),
            }
          end

          def self.entry_value(hash, key)
            return hash[key] if hash.key?(key)

            string_key = key.to_s
            return hash[string_key] if hash.key?(string_key)

            nil
          end
          private_class_method :entry_value
          private_class_method :serialize_destination_entry

          def self.serialize_corrections(corrections)
            return nil if corrections.nil?

            Array(corrections).map do |entry|
              hash =
                if entry.respond_to?(:to_h)
                  entry.to_h
                else
                  entry
                end

              {
                channelKey: hash[:channel_key] || hash["channelKey"],
                submitted: hash[:submitted],
                effective: hash[:effective],
                reasonCode: hash[:reason_code] || hash["reasonCode"],
                reason: hash[:reason],
              }
            end
          end
          private_class_method :serialize_corrections
        end
      end
    end
  end
end
