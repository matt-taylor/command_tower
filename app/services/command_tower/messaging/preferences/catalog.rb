# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Catalog
        def self.call(...)
          new(...).call
        end

        def initialize(recipient_id:, platform_enabled_channels: [])
          @recipient_id = recipient_id
          @platform_enabled_channels = Array(platform_enabled_channels).map(&:to_s).freeze
        end

        def call
          recipient_ready_keys = recipient_ready_channel_keys
          categories = []

          NotificationTypes.catalog.each do |category|
            notifications = []

            category.declarations.each do |declaration|
              next unless declaration.settings_visible

              evaluation = Resolve.call(
                notification_type_key: declaration.key,
                recipient_id: @recipient_id,
                platform_enabled_channels: @platform_enabled_channels,
              )

              notifications << build_notification(declaration, evaluation, recipient_ready_keys)
            end

            next if notifications.empty?

            categories << ::CommandTower::Messaging::Preferences::CatalogCategoryResult.build(
              key: category.key,
              label: category.label,
              description: nil,
              order: category.order,
              notifications:,
            )
          end

          ::CommandTower::Messaging::Preferences::CatalogResult.build(categories:)
        end

        private

        def recipient_ready_channel_keys
          RecipientReadiness.for_recipient(
            recipient_id: @recipient_id,
            platform_enabled_channels: @platform_enabled_channels,
          ).recipient_ready_channel_keys
        rescue RecipientReadiness::RecipientNotFoundError
          []
        end

        def build_notification(declaration, evaluation, recipient_ready_keys)
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

          available =
            declaration.allowed_channels & @platform_enabled_channels & recipient_ready_keys

          ::CommandTower::Messaging::Preferences::CatalogNotificationResult.build(
            key: declaration.key,
            label: declaration.label,
            description: declaration.description,
            order: declaration.type_order,
            configurable: declaration.user_configurable,
            mandatory: declaration.mandatory,
            inbox_available: declaration.inbox_available,
            allowed_channels: declaration.allowed_channels,
            available_channels: available,
            inbox_enabled:,
            channels:,
            stored_override_present: evaluation.stored_override_present,
          )
        end
      end
    end
  end
end
