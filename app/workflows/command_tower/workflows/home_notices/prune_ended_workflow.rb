# frozen_string_literal: true

module CommandTower
  module Workflows
    module HomeNotices
      # Job entry for the daily home notice prune. The host schedules `PruneEndedJob`
      # (or the `command_tower:home_notices:prune` rake task); CommandTower ships no scheduler.
      # A database failure is a failed result, which the job re-raises.
      class PruneEndedWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call
          pruned = CommandTower::Services::HomeNotices::PruneEnded.call
          if pruned.failure?
            return failure(
              errors: pruned.errors, http_status: :internal_server_error, meta: { propagate_to_job: true }
            )
          end

          success(payload: { deleted: pruned.data[:deleted] }, http_status: :ok)
        end
      end
    end
  end
end
