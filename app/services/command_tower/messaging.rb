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
      message_overrides: nil,
      conversation_key: nil,
      conversation_title: nil
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
        conversation_key:,
        conversation_title:,
      )
    end

    def inbox
      Inbox
    end
  end
end
