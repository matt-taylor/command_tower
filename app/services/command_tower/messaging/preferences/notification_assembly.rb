# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class NotificationAssembly
        def self.build(
          declaration:,
          evaluation:,
          available_channels:,
          recipient_id:,
          submitted_destinations: nil
        )
          effective_state = evaluation.effective_preference_state || {}
          effective_channels = effective_state["channels"] || {}
          channels =
            declaration.allowed_channels.to_h do |channel|
              [channel, !!effective_channels[channel]]
            end

          inbox_enabled =
            if effective_state.key?("inbox")
              !!effective_state["inbox"]
            else
              evaluation.inbox_permitted
            end

          channel_catalog = ChannelCatalog.entries_for(declaration)
          destinations = Destinations.call(
            declaration:,
            evaluation:,
            available_channels:,
          )
          corrections =
            if submitted_destinations.nil?
              nil
            else
              built = Corrections.build(submitted: submitted_destinations, destinations:)
              built.empty? ? nil : built
            end

          blocks = EffectiveChoice.call(
            declaration:,
            stored: Store.find(recipient_id:, notification_type_key: declaration.key),
          )

          CatalogNotificationResult.build(
            key: declaration.key,
            label: declaration.label,
            description: declaration.description,
            order: declaration.type_order,
            configurable: declaration.user_configurable,
            mandatory: declaration.mandatory,
            inbox_available: declaration.inbox_available,
            allowed_channels: declaration.allowed_channels,
            available_channels:,
            inbox_enabled:,
            channels:,
            stored_override_present: evaluation.stored_override_present,
            urgency: blocks[:urgency],
            sound: blocks[:sound],
            channel_catalog:,
            destinations:,
            corrections:,
          )
        end
      end
    end
  end
end
