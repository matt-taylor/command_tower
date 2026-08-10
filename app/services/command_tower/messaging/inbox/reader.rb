# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      class Reader
        DEFAULT_LIMIT = 50
        MAX_LIMIT = 100
        SCOPE_INBOX = "inbox"
        SCOPE_ARCHIVED = "archived"
        ALLOWED_SCOPES = [SCOPE_INBOX, SCOPE_ARCHIVED].freeze

        class << self
          def list(recipient_id:, limit: DEFAULT_LIMIT, offset: 0, scope: SCOPE_INBOX)
            recipient_id = require_recipient_id!(recipient_id)
            limit = normalize_limit!(limit)
            offset = normalize_offset!(offset)
            scope = normalize_scope!(scope)

            list_scope =
              if scope == SCOPE_ARCHIVED
                Messaging::InboxItem.archived_list
              else
                Messaging::InboxItem.default_list
              end

            scoped = Scope.for_recipient(recipient_id).merge(list_scope)
            total_count = scoped.count
            records =
              scoped
                .includes(:communication)
                .order(Arel.sql("messaging_inbox_items.created_at DESC, messaging_inbox_items.id DESC"))
                .limit(limit)
                .offset(offset)
                .to_a

            ListResult.build(
              items: records.map { |record| ItemResult.from_record(record) },
              limit:,
              offset:,
              total_count:,
            )
          end

          def show(recipient_id:, inbox_item_id:)
            recipient_id = require_recipient_id!(recipient_id)
            inbox_item_id = require_inbox_item_id!(inbox_item_id)

            record = Scope.find_for_recipient(recipient_id:, inbox_item_id:)
            raise NotFoundError, "inbox item not found" if record.nil? || record.deleted?

            ItemResult.from_record(record)
          end

          def unread_count(recipient_id:)
            recipient_id = require_recipient_id!(recipient_id)

            count = Scope.for_recipient(recipient_id).merge(Messaging::InboxItem.unread).count
            UnreadCountResult.build(recipient_id:, count:)
          end

          private

          def require_recipient_id!(recipient_id)
            raise ValidationError, "recipient_id is required" if blank?(recipient_id)

            recipient_id
          end

          def require_inbox_item_id!(inbox_item_id)
            raise ValidationError, "inbox_item_id is required" if blank?(inbox_item_id)

            inbox_item_id
          end

          def normalize_limit!(limit)
            value = Integer(limit)
            raise ValidationError, "limit must be greater than 0" if value < 1
            raise ValidationError, "limit must be <= #{MAX_LIMIT}" if value > MAX_LIMIT

            value
          rescue ArgumentError, TypeError
            raise ValidationError, "limit must be an integer"
          end

          def normalize_offset!(offset)
            value = Integer(offset)
            raise ValidationError, "offset must be >= 0" if value.negative?

            value
          rescue ArgumentError, TypeError
            raise ValidationError, "offset must be an integer"
          end

          def normalize_scope!(scope)
            value =
              if scope.nil? || (scope.respond_to?(:empty?) && scope.empty?) ||
                   (scope.is_a?(String) && scope.strip.empty?)
                SCOPE_INBOX
              else
                scope.to_s.strip
              end

            raise ValidationError, "scope must be inbox or archived" unless ALLOWED_SCOPES.include?(value)

            value
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
