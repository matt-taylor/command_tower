# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Deletes home notice rows that are finished and idle (design D12).
      #
      # A row is pruned only when its last activity is older than `RETENTION` (180 days):
      # `GREATEST(created_at, last_shown_at, acknowledged_at, dismissed_until)`, each nullable column
      # wrapped in `COALESCE(..., created_at)` because MariaDB `GREATEST` returns NULL when any
      # argument is NULL (a never-shown row would otherwise never be pruned).
      #
      # And it has ended:
      # - delivery: acknowledged, dismissed, or past its `ends_at`
      # - campaign: unacknowledged, or its key is unregistered, or its window has ended (the class
      #   window or the row `ends_at`). An acknowledged row of a live campaign is kept, because
      #   pruning it would show the campaign again.
      #
      # Unregistered keys are never selected, so their rows wait out the retention and are pruned. A
      # key re-registered inside the retention window gets its old state back.
      #
      # Deletes in batches of `BATCH_SIZE`. Success data is `{ deleted: Integer }`. Writes no audit
      # rows. CommandTower ships no scheduler: the host runs the job daily.
      class PruneEnded < CommandTower::Services::ApplicationService
        RETENTION = 180.days
        BATCH_SIZE = 1_000

        LAST_ACTIVITY_SQL = <<~SQL.squish
          GREATEST(
            created_at,
            COALESCE(last_shown_at, created_at),
            COALESCE(acknowledged_at, created_at),
            COALESCE(dismissed_until, created_at)
          )
        SQL

        validate :now, is_a: [Time, ActiveSupport::TimeWithZone], required: false

        def call
          context.deleted = prune
        end

        private

        def current_time
          now || Time.current
        end

        def prune
          scope = idle.merge(ended_deliveries.or(ended_campaigns))
          scope.in_batches(of: BATCH_SIZE).sum(&:delete_all)
        end

        def idle
          CommandTower::HomeNotice.where("#{LAST_ACTIVITY_SQL} < ?", current_time - RETENTION)
        end

        def table
          CommandTower::HomeNotice
        end

        def ended_deliveries
          table.where(kind: "delivery").and(
            table.where.not(acknowledged_at: nil)
                 .or(table.where.not(dismissed_until: nil))
                 .or(table.where(ends_at: ...current_time))
          )
        end

        def ended_campaigns
          table.where(kind: "campaign").and(
            table.where(acknowledged_at: nil)
                 .or(table.where(ends_at: ...current_time))
                 .or(table.where.not(key: live_campaign_keys))
          )
        end

        # Registered campaigns whose class window has not ended.
        def live_campaign_keys
          CommandTower::HomeNotices::Catalog.notices
                                            .select { |klass| klass < CommandTower::HomeNotices::Campaign }
                                            .reject { |klass| window_ended?(klass) }
                                            .map(&:key)
        end

        def window_ended?(klass)
          ends_at = klass.window&.ends_at
          !ends_at.nil? && ends_at <= current_time
        end
      end
    end
  end
end
