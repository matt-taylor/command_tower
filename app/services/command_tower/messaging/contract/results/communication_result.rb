# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        CommunicationResult = Data.define(
          :id,
          :recipient_id,
          :notification_type_key,
          :title,
          :body,
          :metadata,
          :inbox_presentation_snapshot,
          :created_at,
          :destination_plan,
          :inbox_item,
          :channel_deliveries,
        )
      end
    end
  end
end
