# frozen_string_literal: true

module CommandTower
  module Messaging
    class ChannelDeliveryExecutionJob < CommandTower::ApplicationJob
      queue_as :messaging_execution

      # Execution::Recovery is the sole retry coordinator for execution failures.
      # Do not configure ActiveJob retry_on for placeholder/execution failures.

      def perform(channel_delivery_id)
        CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call_from_job(
          channel_delivery_id:,
        )
      end
    end
  end
end
