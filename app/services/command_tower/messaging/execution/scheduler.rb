# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      class Scheduler
        def self.schedule_after_commit(channel_delivery_ids)
          new(channel_delivery_ids).schedule_after_commit
        end

        def initialize(channel_delivery_ids)
          @channel_delivery_ids = Array(channel_delivery_ids).compact.uniq
        end

        def schedule_after_commit
          return if @channel_delivery_ids.empty?

          ids = @channel_delivery_ids
          ActiveRecord.after_all_transactions_commit { enqueue_all(ids) }
        end

        def enqueue_all(ids = @channel_delivery_ids)
          ids.each { |id| enqueue(id) }
        end

        def enqueue(channel_delivery_id)
          Messaging::ChannelDeliveryExecutionJob.perform_later(channel_delivery_id)
          delivery = Messaging::ChannelDelivery.find_by(id: channel_delivery_id)
          OperationLogger.scheduled(channel_delivery: delivery) if delivery
        rescue StandardError => error
          OperationLogger.enqueue_failed(channel_delivery_id:, error:)
          # Leave status as queued — Execution::Recovery will redrive.
          nil
        end
      end
    end
  end
end
