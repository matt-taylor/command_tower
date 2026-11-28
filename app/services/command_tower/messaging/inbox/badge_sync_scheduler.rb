# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Schedules a badge-only push after an inbox change commits. A no-op unless
      # messaging.inbox.badge_sync_push is on, and never while an operator is impersonating
      # (the impersonator must not move the real user's app icon badge). Enqueue failures are
      # swallowed: the badge is best-effort and must never fail the inbox mutation.
      class BadgeSyncScheduler
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
          Messaging::Inbox::BadgeSyncJob.perform_later(@recipient_id)
        rescue StandardError => e
          Rails.logger.warn(
            "[CommandTower::Messaging] badge sync enqueue failed user_id=#{@recipient_id} reason=#{e.class.name}"
          )
          nil
        end

        private

        def enabled?
          CommandTower.config.messaging.inbox.badge_sync_push == true
        end
      end
    end
  end
end
