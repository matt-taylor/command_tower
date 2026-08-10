# frozen_string_literal: true

module CommandTower
  module Messaging
    module_function

    def accept(
      recipient_id:,
      notification_type_key:,
      host_event_identity:,
      title:,
      body:,
      metadata: nil,
      preference_state: nil,
      platform_enabled_channels:,
      message_overrides: nil
    )
      Accept::Coordinator.call(
        recipient_id:,
        notification_type_key:,
        host_event_identity:,
        title:,
        body:,
        metadata:,
        preference_state:,
        platform_enabled_channels:,
        message_overrides:,
      )
    end

    def inbox
      Inbox
    end
  end
end
