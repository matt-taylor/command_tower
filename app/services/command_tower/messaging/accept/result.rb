# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      Result = Data.define(
        :communication_id,
        :destination_plan_id,
        :recipient_id,
        :notification_type_key,
        :host_event_identity,
        :status,
        :idempotent_replay,
        :inbox_item_id,
        :channel_deliveries,
        :selected_channels,
        :inbox_selected,
        :excluded_destinations,
      ) do
        def self.build(
          communication_id:,
          destination_plan_id:,
          recipient_id:,
          notification_type_key:,
          host_event_identity:,
          status:,
          idempotent_replay:,
          inbox_item_id:,
          channel_deliveries:,
          selected_channels:,
          inbox_selected:,
          excluded_destinations:
        )
          ordered_channels = Array(selected_channels).map(&:to_s).uniq.sort.freeze
          ordered_deliveries =
            Array(channel_deliveries).sort_by { |delivery| delivery.channel_key.to_s }.freeze
          ordered_excluded =
            Array(excluded_destinations).sort_by(&:sort_key).freeze

          new(
            communication_id:,
            destination_plan_id:,
            recipient_id:,
            notification_type_key: notification_type_key.to_s,
            host_event_identity: host_event_identity.to_s,
            status: status.to_s,
            idempotent_replay: !!idempotent_replay,
            inbox_item_id:,
            channel_deliveries: ordered_deliveries,
            selected_channels: ordered_channels,
            inbox_selected: !!inbox_selected,
            excluded_destinations: ordered_excluded,
          ).freeze
        end

        def self.from_communication(communication, idempotent_replay:)
          plan = communication.destination_plan
          raise InvariantError, "accepted communication missing destination plan" if plan.nil?

          decision = plan.decision.is_a?(Hash) ? plan.decision : {}
          selected = Array(decision["selected_channels"] || decision[:selected_channels]).map(&:to_s)
          inbox_selected = !!(decision.key?("inbox_selected") ? decision["inbox_selected"] : decision[:inbox_selected])
          excluded =
            Array(decision["excluded_destinations"] || decision[:excluded_destinations]).map do |item|
              hash = item.respond_to?(:to_h) ? item.to_h : item
              ExcludedDestination.build(
                destination: hash["destination"] || hash[:destination],
                reason_class: hash["reason_class"] || hash[:reason_class],
              )
            end

          deliveries =
            Array(communication.channel_deliveries).map do |delivery|
              ChannelDeliveryResult.build(
                id: delivery.id,
                channel_key: delivery.channel_key,
                status: delivery.status,
              )
            end

          build(
            communication_id: communication.id,
            destination_plan_id: plan.id,
            recipient_id: communication.user_id,
            notification_type_key: communication.notification_type_key,
            host_event_identity: communication.host_event_identity,
            status: communication.status,
            idempotent_replay:,
            inbox_item_id: communication.inbox_item&.id,
            channel_deliveries: deliveries,
            selected_channels: selected,
            inbox_selected:,
            excluded_destinations: excluded,
          )
        end
      end
    end
  end
end
