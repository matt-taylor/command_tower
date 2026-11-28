# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Schedules a badge-only push after an inbox change commits. A no-op unless
      # messaging.inbox.badge_sync_push is on, and never while an operator is impersonating
      # (the impersonator must not move the real user's app icon badge). Enqueue failures are
      # swallowed: the badge is best-effort and must never fail the inbox mutation.
      class BadgeSyncScheduler
        PENDING_TTL_SECONDS = 60
        ENQUEUE_WAIT = 5.seconds

        def self.marker_key(recipient_id)
          "command_tower:messaging:inbox:badge_sync:pending:#{recipient_id}"
        end

        def self.schedule_after_commit(recipient_id)
          new(recipient_id).schedule_after_commit
        end

        def self.enqueue(recipient_id)
          new(recipient_id).enqueue
        end

        def initialize(recipient_id)
          @recipient_id = recipient_id
        end

        def schedule_after_commit
          return unless enabled?
          return if ImpersonationAudit.impersonating?

          ActiveRecord.after_all_transactions_commit { enqueue }
        end

        def enqueue
          return nil unless claim_pending_marker

          Messaging::Inbox::BadgeSyncJob.set(wait: ENQUEUE_WAIT).perform_later(@recipient_id)
        rescue StandardError => e
          release_pending_marker
          Rails.logger.warn(
            "[CommandTower::Messaging] badge sync enqueue failed user_id=#{@recipient_id} reason=#{e.class.name}"
          )
          nil
        end

        private

        def enabled?
          CommandTower.config.messaging.inbox.badge_sync_push == true
        end

        # True when this call owns the enqueue; false when a job is already pending for the recipient
        # (it clears the marker before reading the count, so it will see this change). Fails open
        # (true) when Redis is unavailable.
        def claim_pending_marker
          CommandTower::RedisConnection.with do |redis|
            redis.set(self.class.marker_key(@recipient_id), "1", nx: true, ex: PENDING_TTL_SECONDS) ? true : false
          end
        rescue Redis::BaseError, Timeout::Error
          true
        end

        def release_pending_marker
          CommandTower::RedisConnection.with { |redis| redis.del(self.class.marker_key(@recipient_id)) }
        rescue Redis::BaseError, Timeout::Error
          nil
        end
      end
    end
  end
end
