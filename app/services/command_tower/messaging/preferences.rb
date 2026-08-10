# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      module_function

      def evaluate(
        notification_type_key:,
        recipient_id:,
        preference_state: nil,
        platform_enabled_channels: []
      )
        Evaluator.call(
          notification_type_key:,
          recipient_id:,
          preference_state:,
          platform_enabled_channels:,
        )
      end

      def resolve(
        notification_type_key:,
        recipient_id:,
        platform_enabled_channels: []
      )
        Resolve.call(
          notification_type_key:,
          recipient_id:,
          platform_enabled_channels:,
        )
      end

      def catalog(recipient_id:, platform_enabled_channels: [])
        Catalog.call(
          recipient_id:,
          platform_enabled_channels:,
        )
      end

      def find_stored(recipient_id:, notification_type_key:)
        Store.find(recipient_id:, notification_type_key:)
      end

      def upsert_stored!(recipient_id:, notification_type_key:, preference_state:)
        Store.upsert!(recipient_id:, notification_type_key:, preference_state:)
      end

      def delete_stored!(recipient_id:, notification_type_key:)
        Store.delete!(recipient_id:, notification_type_key:)
      end

      def update(
        recipient_id:,
        notification_type_key:,
        preference_state:,
        platform_enabled_channels: []
      )
        Update.call(
          recipient_id:,
          notification_type_key:,
          preference_state:,
          platform_enabled_channels:,
        )
      end
    end
  end
end
