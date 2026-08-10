# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      module_function

      def plan(
        notification_type_key:,
        recipient_id:,
        preference_state: nil,
        platform_enabled_channels: [],
        message_overrides: nil
      )
        ::CommandTower::Messaging::Planner::Planner.call(
          notification_type_key:,
          recipient_id:,
          preference_state:,
          platform_enabled_channels:,
          message_overrides:,
        )
      end
    end
  end
end
