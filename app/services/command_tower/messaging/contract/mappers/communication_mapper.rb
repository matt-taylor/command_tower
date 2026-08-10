# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Mappers
        class CommunicationMapper
          def self.to_result(communication)
            new(communication).to_result
          end

          def initialize(communication)
            @communication = communication
          end

          def to_result
            result = Results::CommunicationResult.new(
              id: communication.id,
              recipient_id: communication.user_id,
              notification_type_key: communication.notification_type_key,
              title: communication.title,
              body: communication.body,
              metadata: freeze_metadata(communication.metadata),
              created_at: communication.created_at,
              destination_plan: DestinationPlanMapper.to_result(communication.destination_plan),
              inbox_item: InboxItemMapper.to_result(communication.inbox_item),
              channel_deliveries: communication.channel_deliveries.map do |delivery|
                ChannelDeliveryMapper.to_result(delivery)
              end.freeze,
            ).freeze
            assert_no_active_record!(result)
            result
          end

          private

          attr_reader :communication

          def freeze_metadata(metadata)
            return nil if metadata.nil?

            metadata.to_h.transform_keys(&:to_s).freeze
          end

          def assert_no_active_record!(value)
            if value.is_a?(ActiveRecord::Base)
              raise Contract::InvariantError, "ActiveRecord must not leak through contract results"
            end

            case value
            when Array
              value.each { |item| assert_no_active_record!(item) }
            when Data
              value.members.each { |member| assert_no_active_record!(value.public_send(member)) }
            end
          end
        end
      end
    end
  end
end
