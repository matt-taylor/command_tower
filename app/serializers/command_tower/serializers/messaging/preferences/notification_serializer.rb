# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Preferences
        class NotificationSerializer
          def self.serialize(notification)
            {
              key: notification.key,
              label: notification.label,
              description: notification.description,
              order: notification.order,
              configurable: notification.configurable,
              mandatory: notification.mandatory,
              inboxAvailable: notification.inbox_available,
              allowedChannels: notification.allowed_channels,
              availableChannels: notification.available_channels,
              preferences: {
                inboxEnabled: notification.inbox_enabled,
                channels: notification.channels,
                storedOverridePresent: notification.stored_override_present,
              },
            }
          end
        end
      end
    end
  end
end
