# frozen_string_literal: true

module CommandTower
  module Messaging
    module Communications
      class ProduceRecipientJob < CommandTower::ApplicationJob
        queue_as :messaging_produce_fanout

        def perform(user_id, attrs)
          attrs = attrs.stringify_keys
          CommandTower::Workflows::Messaging::Communications::ProduceRecipientWorkflow.call_from_job(
            user_id:,
            notification_type_key: attrs.fetch("notification_type_key"),
            campaign_identity: attrs.fetch("campaign_identity"),
            title: attrs.fetch("title"),
            body: attrs.fetch("body"),
            platform_enabled_channels: Array(attrs["platform_enabled_channels"]),
            metadata: attrs["metadata"],
          )
        end
      end
    end
  end
end
