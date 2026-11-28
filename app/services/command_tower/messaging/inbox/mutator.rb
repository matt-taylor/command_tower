# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      class Mutator
        # Bulk-operation ceiling. Intentionally independent from Reader::MAX_LIMIT:
        # list page size and the number of items a recipient may mutate in one
        # transaction are tuned separately.
        BULK_MAX_IDS = 100

        # Operations that require a live row; a soft-deleted item is not available to them.
        LIVE_ROW_OPERATIONS = %i[mark_viewed mark_unviewed archive restore].freeze

        class << self
          def mark_viewed(recipient_id:, inbox_item_id:)
            mutate(recipient_id:, inbox_item_id:, operation: :mark_viewed)
          end

          # Keyed by communication. Returns nil when the communication is not the
          # recipient's, has no inbox item, or the item is deleted. Idempotent:
          # result.newly_viewed is true only on the call that set viewed_at.
          def mark_viewed_for_communication(recipient_id:, communication_id:)
            recipient_id = require_recipient_id!(recipient_id)
            raise ValidationError, "communication_id is required" if blank?(communication_id)

            record = Scope.find_for_recipient_communication(recipient_id:, communication_id:)
            return nil if record.nil? || record.deleted?

            mark_viewed(recipient_id:, inbox_item_id: record.id)
          rescue NotFoundError
            nil
          end

          # Host-driven, keyed by the communication idempotency namespace. Idempotent,
          # never touches viewed_at, emits no audit. Returns nil when there is no live
          # inbox item for the recipient and event.
          def resolve_for_event(recipient_id:, notification_type_key:, host_event_identity:)
            set_resolved(recipient_id:, notification_type_key:, host_event_identity:, resolved: true)
          end

          def unresolve_for_event(recipient_id:, notification_type_key:, host_event_identity:)
            set_resolved(recipient_id:, notification_type_key:, host_event_identity:, resolved: false)
          end

          def mark_unviewed(recipient_id:, inbox_item_id:)
            mutate(recipient_id:, inbox_item_id:, operation: :mark_unviewed)
          end

          def archive(recipient_id:, inbox_item_id:)
            mutate(recipient_id:, inbox_item_id:, operation: :archive)
          end

          def restore(recipient_id:, inbox_item_id:)
            mutate(recipient_id:, inbox_item_id:, operation: :restore)
          end

          def delete(recipient_id:, inbox_item_id:)
            mutate(recipient_id:, inbox_item_id:, operation: :delete)
          end

          def bulk_mark_viewed(recipient_id:, inbox_item_ids:)
            bulk_mutate(recipient_id:, inbox_item_ids:, operation: :mark_viewed)
          end

          def bulk_mark_unviewed(recipient_id:, inbox_item_ids:)
            bulk_mutate(recipient_id:, inbox_item_ids:, operation: :mark_unviewed)
          end

          def bulk_archive(recipient_id:, inbox_item_ids:)
            bulk_mutate(recipient_id:, inbox_item_ids:, operation: :archive)
          end

          def bulk_restore(recipient_id:, inbox_item_ids:)
            bulk_mutate(recipient_id:, inbox_item_ids:, operation: :restore)
          end

          def bulk_delete(recipient_id:, inbox_item_ids:)
            bulk_mutate(recipient_id:, inbox_item_ids:, operation: :delete)
          end

          # Scroll-read: marks every available id viewed in one transaction. Unlike bulk_mark_viewed,
          # ids that are missing, another recipient's or deleted do not fail the batch; they are
          # returned together as unavailable_ids. newly_viewed lists only first views.
          def record_views(recipient_id:, inbox_item_ids:)
            recipient_id = require_recipient_id!(recipient_id)
            requested_ids = require_inbox_item_ids!(inbox_item_ids)

            viewed_ids = []
            newly_viewed = []

            ActiveRecord::Base.transaction do
              records_by_id = Scope.for_recipient(recipient_id).lock.where(id: requested_ids).index_by { |record| record.id.to_s }
              requested_ids.each do |requested_id|
                record = records_by_id[requested_id.to_s]
                next if record.nil? || record.deleted?

                viewed_ids << record.id
                newly_viewed << { id: record.id, communication_id: record.communication_id } if apply_mark_viewed(record) == :changed
              end
            end

            log_bulk_lifecycle(recipient_id:, operation: :mark_viewed, changed_ids: newly_viewed.pluck(:id))

            unavailable_ids = requested_ids.reject { |requested_id| viewed_ids.include?(requested_id.to_i) }
            RecordViewsResult.new(viewed_ids:, newly_viewed:, unavailable_ids:).freeze
          end

          # Marks every row that counts as unread (live, not archived, not resolved) with
          # id <= up_to viewed, in one transaction. Rows above the watermark, archived,
          # resolved and deleted rows are left untouched, so an Archived-segment call is a no-op.
          # Locked in id order so concurrent callers cannot deadlock.
          def mark_all_read(recipient_id:, up_to:)
            recipient_id = require_recipient_id!(recipient_id)
            raise ValidationError, "up_to must be a positive integer" unless up_to.is_a?(Integer) && up_to.positive?

            changed_ids = []

            ActiveRecord::Base.transaction do
              Scope.for_recipient(recipient_id).merge(Messaging::InboxItem.counts_as_unread)
                   .where(id: ..up_to).order(:id).lock.each do |record|
                changed_ids << record.id if apply_mark_viewed(record) == :changed
              end
              audit_impersonated_changes(recipient_id:, action: :mark_all_read, changed_ids:, up_to:)
            end

            log_bulk_lifecycle(recipient_id:, operation: :mark_viewed, changed_ids:)
            schedule_badge_sync(recipient_id) if changed_ids.any?

            BulkResult.build(ids: changed_ids, changed_count: changed_ids.size)
          end

          private

          def schedule_badge_sync(recipient_id)
            BadgeSyncScheduler.schedule_after_commit(recipient_id)
          end

          def set_resolved(recipient_id:, notification_type_key:, host_event_identity:, resolved:)
            recipient_id = require_recipient_id!(recipient_id)
            raise ValidationError, "notification_type_key is required" if blank?(notification_type_key)
            raise ValidationError, "host_event_identity is required" if blank?(host_event_identity)

            communication = Messaging::Communication.find_by_idempotency_namespace(
              user_id: recipient_id, notification_type_key:, host_event_identity:,
            )
            return nil if communication.nil?

            result = ActiveRecord::Base.transaction do
              flip_resolved(recipient_id:, communication_id: communication.id, resolved:)
            end
            schedule_badge_sync(recipient_id) if result&.changed
            result
          end

          def flip_resolved(recipient_id:, communication_id:, resolved:)
            record = Scope.find_for_recipient_communication(recipient_id:, communication_id:, lock: true)
            return nil if record.nil? || record.deleted?

            changed = record.resolved? != resolved
            record.update!(resolved_at: resolved ? Time.current : nil) if changed

            ResolutionResult.new(
              communication_id:, inbox_item_id: record.id, resolved: record.resolved?, changed:,
            ).freeze
          end

          def mutate(recipient_id:, inbox_item_id:, operation:)
            recipient_id = require_recipient_id!(recipient_id)
            inbox_item_id = require_inbox_item_id!(inbox_item_id)

            result = nil
            outcome = nil

            ActiveRecord::Base.transaction do
              record = Scope.find_for_recipient(
                recipient_id:,
                inbox_item_id:,
                lock: true,
              )
              raise NotFoundError, "inbox item not found" if record.nil?
              raise NotFoundError, "inbox item not found" unless available_for?(operation, record)

              outcome = apply(operation, record)
              record.reload
              result = ItemResult.from_record(record)
              audit_impersonated_changes(recipient_id:, action: operation, changed_ids: outcome == :changed ? [record.id] : [])
            end

            if outcome == :changed
              OperationLogger.after_commit { OperationLogger.lifecycle_changed(operation:, item: result) }
              schedule_badge_sync(recipient_id)
            end

            result = result.with(newly_viewed: true) if operation == :mark_viewed && outcome == :changed

            result
          end

          # Atomic batch: every id is validated for the recipient and the operation
          # before any row is mutated, so a batch never partially persists.
          def bulk_mutate(recipient_id:, inbox_item_ids:, operation:)
            recipient_id = require_recipient_id!(recipient_id)
            requested_ids = require_inbox_item_ids!(inbox_item_ids)

            ids = []
            changed_ids = []

            ActiveRecord::Base.transaction do
              lock_all_for_recipient!(recipient_id:, requested_ids:, operation:).each do |record|
                ids << record.id
                changed_ids << record.id if apply(operation, record) == :changed
              end
              audit_impersonated_changes(recipient_id:, action: :"bulk_#{operation}", changed_ids:)
            end

            log_bulk_lifecycle(recipient_id:, operation:, changed_ids:)
            schedule_badge_sync(recipient_id) if changed_ids.any?

            BulkResult.build(ids:, changed_count: changed_ids.size)
          end

          def lock_all_for_recipient!(recipient_id:, requested_ids:, operation:)
            records_by_id =
              Scope
                .for_recipient(recipient_id)
                .lock
                .where(id: requested_ids)
                .index_by { |record| record.id.to_s }

            invalid_ids = requested_ids.reject do |requested_id|
              record = records_by_id[requested_id.to_s]
              record && available_for?(operation, record)
            end

            if invalid_ids.any?
              raise InvalidBulkItemsError.new(
                "inbox items are unavailable for #{operation}",
                invalid_ids:,
              )
            end

            requested_ids.map { |requested_id| records_by_id.fetch(requested_id.to_s) }
          end

          # Called inside the mutation transaction; emits at most one audit event per request.
          def audit_impersonated_changes(recipient_id:, action:, changed_ids:, up_to: nil)
            ImpersonationAudit.record_changes(recipient_id:, action:, changed_ids:, up_to:)
          end

          # Logs after the outermost transaction commits, one lifecycle event per actually-changed item.
          def log_bulk_lifecycle(recipient_id:, operation:, changed_ids:)
            return if changed_ids.empty?

            OperationLogger.after_commit do
              records_by_id =
                Scope
                  .for_recipient(recipient_id)
                  .includes(:communication)
                  .where(id: changed_ids)
                  .index_by(&:id)

              changed_ids.each do |changed_id|
                record = records_by_id[changed_id]
                next if record.nil?

                OperationLogger.lifecycle_changed(
                  operation:,
                  item: ItemResult.from_record(record),
                  bulk: true,
                )
              end
            end
          end

          def available_for?(operation, record)
            return true unless LIVE_ROW_OPERATIONS.include?(operation)

            !record.deleted?
          end

          def apply(operation, record)
            case operation
            when :mark_viewed then apply_mark_viewed(record)
            when :mark_unviewed then apply_mark_unviewed(record)
            when :archive then apply_archive(record)
            when :restore then apply_restore(record)
            when :delete then apply_delete(record)
            else raise InvariantError, "unknown inbox operation #{operation}"
            end
          end

          def apply_mark_viewed(record)
            return :noop unless record.viewed_at.nil?

            attrs = { viewed_at: Time.current }
            attrs[:status] = Messaging::InboxItem::STATUS_VIEWED unless record.archived?
            record.update!(attrs)
            :changed
          end

          def apply_mark_unviewed(record)
            return :noop if record.viewed_at.nil?

            attrs = { viewed_at: nil }
            attrs[:status] = Messaging::InboxItem::STATUS_CREATED unless record.archived?
            record.update!(attrs)
            :changed
          end

          def apply_archive(record)
            return :noop unless record.archived_at.nil?

            record.update!(
              archived_at: Time.current,
              status: Messaging::InboxItem::STATUS_ARCHIVED,
            )
            :changed
          end

          def apply_restore(record)
            return :noop if record.archived_at.nil?

            status =
              if record.viewed_at.nil?
                Messaging::InboxItem::STATUS_CREATED
              else
                Messaging::InboxItem::STATUS_VIEWED
              end
            record.update!(archived_at: nil, status:)
            :changed
          end

          def apply_delete(record)
            return :noop unless record.deleted_at.nil?

            record.update!(
              deleted_at: Time.current,
              status: Messaging::InboxItem::STATUS_DELETED,
            )
            :changed
          end

          def require_recipient_id!(recipient_id)
            raise ValidationError, "recipient_id is required" if blank?(recipient_id)

            recipient_id
          end

          def require_inbox_item_id!(inbox_item_id)
            raise ValidationError, "inbox_item_id is required" if blank?(inbox_item_id)

            inbox_item_id
          end

          def require_inbox_item_ids!(inbox_item_ids)
            raise ValidationError, "inbox_item_ids must be an array" unless inbox_item_ids.is_a?(Array)
            raise ValidationError, "inbox_item_ids must not contain blank ids" if inbox_item_ids.any? { |id| blank?(id) }

            ids = inbox_item_ids.uniq(&:to_s)
            raise ValidationError, "inbox_item_ids is required" if ids.empty?
            raise ValidationError, "inbox_item_ids must contain at most #{BULK_MAX_IDS} ids" if ids.size > BULK_MAX_IDS

            ids
          end

          def blank?(value)
            value.nil? || (value.respond_to?(:empty?) && value.empty?) ||
              (value.is_a?(String) && value.strip.empty?)
          end
        end
      end
    end
  end
end
