# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # Daily prune of ended, idle home notice rows. Scheduled by the host.
    class PruneEndedJob < CommandTower::ApplicationJob
      queue_as :default

      def perform
        execute_workflow(CommandTower::Workflows::HomeNotices::PruneEndedWorkflow)
      end
    end
  end
end
