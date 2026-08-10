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

          private

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
            end

            if outcome == :changed
              OperationLogger.lifecycle_changed(operation:, item: result)
            end

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
            end

            log_bulk_lifecycle(recipient_id:, operation:, changed_ids:)

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

          # Logs post-commit, one lifecycle event per actually-changed item.
          def log_bulk_lifecycle(recipient_id:, operation:, changed_ids:)
            return if changed_ids.empty?

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
