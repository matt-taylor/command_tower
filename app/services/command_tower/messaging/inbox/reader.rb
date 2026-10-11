# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      class Reader
        DEFAULT_LIMIT = 50
        MAX_LIMIT = 100
        WINDOW_LIMIT = 5
        WINDOW_MAX_OLDER = 2
        OLDEST_UNREAD = "oldest_unread"
        SCOPE_INBOX = "inbox"
        SCOPE_ARCHIVED = "archived"
        ALLOWED_SCOPES = [SCOPE_INBOX, SCOPE_ARCHIVED].freeze

        class << self
          def list(recipient_id:, limit: DEFAULT_LIMIT, offset: 0, scope: SCOPE_INBOX)
            recipient_id = require_recipient_id!(recipient_id)
            limit = normalize_limit!(limit)
            offset = normalize_offset!(offset)
            scope = normalize_scope!(scope)

            scoped = Scope.for_recipient(recipient_id).merge(list_scope_for(scope))
            page_rows = entry_page_rows(scoped, limit:, offset:)
            members = page_members(scoped, page_rows)

            ListResult.build(
              items: page_rows.map { |row| build_entry(row, members) },
              limit:,
              offset:,
              total_count: entry_count(scoped),
            )
          end

          def conversation(recipient_id:, key:, scope: SCOPE_INBOX, around: nil, before_id: nil, after_id: nil, limit: nil)
            recipient_id = require_recipient_id!(recipient_id)
            raise ValidationError, "key is required" if blank?(key)

            scope = normalize_scope!(scope)
            records = members_for_key(recipient_id:, key:, scope:)
            raise NotFoundError, "conversation not found" if records.empty?

            window = conversation_window(records, around:, before_id:, after_id:, limit:)
            latest = records.last
            ConversationResult.build(
              scope:,
              subject: latest.communication.conversation_title,
              message_count: records.size,
              unread_count: records.count { |record| record.viewed_at.nil? },
              inbox_item_ids: records.map(&:id),
              message_ids: window ? window.fetch(:message_ids) : records.map(&:id),
              window: window&.except(:message_ids),
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

          def list_scope_for(scope)
            if scope == SCOPE_ARCHIVED
              Messaging::InboxItem.archived_list
            else
              Messaging::InboxItem.default_list
            end
          end

          def entry_page_rows(scoped, limit:, offset:)
            sql = <<~SQL.squish
              SELECT conversation_key, inbox_item_id AS latest_id, item_created_at AS activity_at
              FROM (
                SELECT
                  members.*,
                  ROW_NUMBER() OVER (
                    PARTITION BY entry_group
                    ORDER BY item_created_at DESC, inbox_item_id DESC
                  ) AS recency_rank
                FROM (#{member_groups_sql(scoped)}) members
              ) ranked
              WHERE recency_rank = 1
              ORDER BY activity_at DESC, latest_id DESC
              LIMIT #{limit} OFFSET #{offset}
            SQL

            Messaging::InboxItem.connection.select_all(sql).to_a
          end

          def entry_count(scoped)
            sql = <<~SQL.squish
              SELECT COUNT(*) FROM (
                SELECT entry_group
                FROM (#{member_groups_sql(scoped)}) members
                GROUP BY entry_group
              ) entry_groups
            SQL

            Messaging::InboxItem.connection.select_value(sql).to_i
          end

          def member_groups_sql(scoped)
            scoped.select(Arel.sql(<<~SQL.squish)).to_sql
              messaging_inbox_items.id AS inbox_item_id,
              messaging_inbox_items.created_at AS item_created_at,
              messaging_communications.conversation_key AS conversation_key,
              CASE
                WHEN messaging_communications.conversation_key IS NULL
                  THEN CONCAT('m:', messaging_inbox_items.id)
                ELSE CONCAT('c:', messaging_communications.conversation_key)
              END AS entry_group
            SQL
          end

          def page_members(scoped, page_rows)
            keys = page_rows.filter_map { |row| row_value(row, "conversation_key").presence }
            standalone_ids = page_rows.filter_map do |row|
              next if row_value(row, "conversation_key").present?

              Integer(row_value(row, "latest_id"))
            end
            ids = standalone_ids.dup
            if keys.any?
              ids.concat(
                scoped.where(messaging_communications: { conversation_key: keys }).pluck("messaging_inbox_items.id"),
              )
            end
            return [] if ids.empty?

            scoped.where(messaging_inbox_items: { id: ids }).includes(:communication).to_a
          end

          def build_entry(row, members)
            latest_id = Integer(row_value(row, "latest_id"))
            key = row_value(row, "conversation_key").presence
            group =
              if key
                members.select { |member| member.communication.conversation_key == key }
              else
                members.select { |member| member.id == latest_id }
              end
            group = group.sort_by { |member| [member.created_at, member.id] }
            latest = group.find { |member| member.id == latest_id }
            raise InvariantError, "latest inbox member missing" if latest.nil?

            conversation = key.present?
            EntryResult.build(
              kind: conversation ? "conversation" : "message",
              id: conversation ? key : latest.id,
              title: conversation ? latest.communication.conversation_title : latest.communication.title,
              preview: conversation ? latest.communication.title : nil,
              activity_at: latest.created_at,
              message_count: group.size,
              unread_count: group.count { |member| member.viewed_at.nil? },
              inbox_item_ids: group.map(&:id),
            )
          end

          def conversation_window(records, around:, before_id:, after_id:, limit:)
            windowed = !around.nil? || !before_id.nil? || !after_id.nil?
            unless windowed
              raise ValidationError, "invalid_limit" unless limit.nil?

              return
            end

            modes = [around, before_id, after_id].count { |value| !value.nil? }
            raise ValidationError, "invalid_window" unless modes == 1

            page_limit = normalize_window_limit!(limit)
            cursor = nil
            anchor = nil
            slice =
              if !around.nil?
                anchor = resolve_anchor(records, around)
                around_slice(records, anchor, page_limit)
              elsif !before_id.nil?
                cursor = find_member!(records, before_id)
                records.select { |record| before_record?(record, cursor) }.last(page_limit)
              else
                cursor = find_member!(records, after_id)
                records.select { |record| before_record?(cursor, record) }.first(page_limit)
              end

            flags = window_flags(records, slice, cursor)
            {
              message_ids: slice.map(&:id),
              anchor_inbox_item_id: anchor&.id,
              has_before: flags.fetch(:has_before),
              has_after: flags.fetch(:has_after),
              before_cursor: flags.fetch(:before_cursor),
              after_cursor: flags.fetch(:after_cursor),
            }
          end

          def resolve_anchor(records, around)
            return records.find { |record| record.viewed_at.nil? } || records.last if around.to_s == OLDEST_UNREAD

            find_member!(records, around)
          end

          def around_slice(records, anchor, limit)
            index = records.index(anchor)
            before_count = [WINDOW_MAX_OLDER, index, limit - 1].min
            after_count = [limit - 1 - before_count, records.length - 1 - index].min
            records[(index - before_count)..(index + after_count)]
          end

          def find_member!(records, inbox_item_id)
            id = Integer(inbox_item_id)
            records.find { |record| record.id == id } || raise(ValidationError, "invalid_cursor")
          rescue ArgumentError, TypeError
            raise ValidationError, "invalid_cursor"
          end

          def window_flags(records, slice, cursor)
            if slice.any?
              first = slice.first
              last = slice.last
              {
                has_before: records.any? { |record| before_record?(record, first) },
                has_after: records.any? { |record| before_record?(last, record) },
                before_cursor: first.id,
                after_cursor: last.id,
              }
            else
              {
                has_before: !cursor.nil? && records.any? { |record| before_record?(record, cursor) },
                has_after: !cursor.nil? && records.any? { |record| before_record?(cursor, record) },
                before_cursor: nil,
                after_cursor: nil,
              }
            end
          end

          def before_record?(candidate, boundary)
            return candidate.id < boundary.id if candidate.created_at == boundary.created_at

            candidate.created_at < boundary.created_at
          end

          def normalize_window_limit!(limit)
            value = limit.nil? ? WINDOW_LIMIT : Integer(limit)
            raise ValidationError, "invalid_limit" if value < 1 || value > WINDOW_LIMIT

            value
          rescue ArgumentError, TypeError
            raise ValidationError, "invalid_limit"
          end

          def members_for_key(recipient_id:, key:, scope:)
            Scope.for_recipient(recipient_id)
              .merge(list_scope_for(scope))
              .includes(:communication)
              .where(messaging_communications: { conversation_key: key })
              .order(Arel.sql("messaging_inbox_items.created_at ASC, messaging_inbox_items.id ASC"))
              .to_a
          end

          def row_value(row, key)
            row[key] || row[key.to_sym]
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
