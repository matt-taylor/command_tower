# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      # D7. After a new inbox item commits, restores the recipient's archived, non-deleted,
      # non-resolved members of the same conversation. Owns its transaction (so it runs after
      # the outermost commit and can retry a deadlock in place). Locks members in id order.
      # A lost restore leaves a partial thread, which the reader already tolerates.
      class ThreadRestorer
        DEADLOCK_RETRIES = 3

        def self.call(inbox_item_id)
          new(inbox_item_id).call
        end

        def initialize(inbox_item_id)
          @inbox_item_id = inbox_item_id
        end

        def call
          attempts = 0
          begin
            attempts += 1
            restore_members
          rescue ActiveRecord::Deadlocked
            retry if attempts <= DEADLOCK_RETRIES

            log_failure("deadlock")
          end
        rescue StandardError => e
          log_failure(e.class.name)
        end

        def restore_members
          ActiveRecord::Base.transaction do
            ids = lock_member_ids
            next if ids.empty?

            apply_restore(ids)
          end
        end

        private

        def conversation_communication_ids
          item = Messaging::InboxItem.includes(:communication).find_by(id: @inbox_item_id)
          return Messaging::Communication.none if item.nil?

          Messaging::Communication.where(
            user_id: item.communication.user_id,
            conversation_key: item.communication.conversation_key
          ).select(:id)
        end

        def lock_member_ids
          Messaging::InboxItem
            .where(communication_id: conversation_communication_ids)
            .where.not(id: @inbox_item_id)
            .archived.not_deleted.unresolved
            .order(:id)
            .lock
            .pluck(:id)
        end

        # Same result as the Mutator's apply_restore, set-based. update_all is deliberate: the
        # rows are already locked and there are no validations or callbacks on this model.
        def apply_restore(ids)
          Messaging::InboxItem.where(id: ids).update_all( # rubocop:disable Rails/SkipsModelValidations
            [
              "archived_at = NULL, updated_at = ?, status = CASE WHEN viewed_at IS NULL THEN ? ELSE ? END",
              Time.current,
              Messaging::InboxItem::STATUS_CREATED,
              Messaging::InboxItem::STATUS_VIEWED
            ]
          )
        end

        def log_failure(reason)
          Rails.logger.warn(
            "[CommandTower::Messaging] thread restore failed inbox_item_id=#{@inbox_item_id} reason=#{reason}"
          )
        end
      end
    end
  end
end
