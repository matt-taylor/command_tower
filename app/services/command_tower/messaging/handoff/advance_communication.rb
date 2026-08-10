# frozen_string_literal: true

module CommandTower
  module Messaging
    module Handoff
      # Owns the handoff write transaction: planned → queued + execution_handoff_status.
      class AdvanceCommunication
        def self.call(communication:)
          new(communication:).call
        end

        def initialize(communication:)
          @communication = communication
        end

        def call
          ActiveRecord::Base.transaction do
            @communication.channel_deliveries.each do |delivery|
              next unless delivery.status == Messaging::ChannelDelivery::STATUS_PLANNED

              delivery.update!(status: Messaging::ChannelDelivery::STATUS_QUEUED)
            end

            next_status =
              if @communication.channel_deliveries.reload.empty?
                Messaging::Communication::HANDOFF_COMPLETE
              else
                Messaging::Communication::HANDOFF_ENQUEUED
              end

            @communication.update!(execution_handoff_status: next_status)
          end

          @communication.reload
        end
      end
    end
  end
end
