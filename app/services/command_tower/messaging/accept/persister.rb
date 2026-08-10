# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      class Persister
        def self.call(request:, plan:, fingerprint:)
          new(request:, plan:, fingerprint:).call
        end

        def initialize(request:, plan:, fingerprint:)
          @request = request
          @plan = plan
          @fingerprint = fingerprint
        end

        def call
          communication = nil

          ActiveRecord::Base.transaction do
            communication = Messaging::Communication.create!(
              user_id: @request.fetch(:recipient_id),
              notification_type_key: @request.fetch(:notification_type_key).to_s,
              host_event_identity: @request.fetch(:host_event_identity).to_s,
              accept_request_fingerprint: @fingerprint,
              status: Messaging::Communication::STATUS_ACCEPTED,
              execution_handoff_status: Messaging::Communication::HANDOFF_PENDING,
              title: @request.fetch(:title),
              body: @request.fetch(:body),
              metadata: freeze_metadata(@request[:metadata]),
            )

            Messaging::DestinationPlan.create!(
              communication:,
              decision: decision_payload(@plan),
            )

            if @plan.inbox_selected
              Messaging::InboxItem.create!(
                communication:,
                status: Messaging::InboxItem::STATUS_CREATED,
              )
            end

            @plan.selected_channels.each do |channel_key|
              Messaging::ChannelDelivery.create!(
                communication:,
                channel_key: channel_key.to_s,
                status: Messaging::ChannelDelivery::STATUS_PLANNED,
              )
            end
          end

          reload_aggregate(communication.id)
        end

        private

        def freeze_metadata(metadata)
          return nil if metadata.nil?

          metadata.to_h.transform_keys(&:to_s)
        end

        def decision_payload(plan)
          {
            "selected_channels" => Array(plan.selected_channels).map(&:to_s),
            "inbox_selected" => !!plan.inbox_selected,
            "mandatory" => !!plan.mandatory,
            "platform_enabled_channels" => Array(@request[:platform_enabled_channels]).map(&:to_s),
            "excluded_destinations" => Array(plan.excluded_destinations).map do |excluded|
              {
                "destination" => excluded.destination == :inbox ? "inbox" : excluded.destination.to_s,
                "reason_class" => excluded.reason_class.to_s,
              }
            end,
          }
        end

        def reload_aggregate(id)
          Messaging::Communication.includes(
            :destination_plan,
            :inbox_item,
            :channel_deliveries,
          ).find(id)
        end
      end
    end
  end
end
