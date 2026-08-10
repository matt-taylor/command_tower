# frozen_string_literal: true

module CommandTower
  module Messaging
    class HandoffJob < CommandTower::ApplicationJob
      queue_as :messaging_handoff

      def perform(communication_id)
        CommandTower::Workflows::Messaging::Handoff::ProcessWorkflow.call_from_job(
          communication_id:,
        )
      end
    end
  end
end
