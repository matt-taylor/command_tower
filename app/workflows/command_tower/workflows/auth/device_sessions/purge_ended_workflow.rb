# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module DeviceSessions
        # Deletes device sessions that ended (revoked, or past their absolute expiry)
        # more than `retain_for` ago. Walks the indexed `revoked_at` and
        # `absolute_expires_at` columns in id-bounded batches so no statement is large.
        # Idle-expired rows are not purged here: they are ended only by `last_seen_at`,
        # which is unindexed, and they reach absolute expiry in time.
        class PurgeEndedWorkflow < CommandTower::Workflows::ApplicationWorkflow
          BATCH_SIZE = 1_000
          DEFAULT_RETAIN_FOR = 7.days

          retry_strategy :none

          def call(retain_for: DEFAULT_RETAIN_FOR)
            cutoff = Time.current - retain_for
            scope = CommandTower::Auth::DeviceSession
            purged = purge(scope.where(revoked_at: ...cutoff))
            purged += purge(scope.where(absolute_expires_at: ...cutoff))

            log_info("Purged #{purged} ended device sessions")
            success(payload: { purged: purged }, http_status: :ok)
          end

          private

          def purge(scope)
            total = 0
            loop do
              ids = scope.limit(BATCH_SIZE).pluck(:id)
              break if ids.empty?

              total += CommandTower::Auth::DeviceSession.where(id: ids).delete_all
            end
            total
          end
        end
      end
    end
  end
end
