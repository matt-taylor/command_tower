# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Messaging
      module Inbox
        class ListDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:limit, :offset, :scope)
          DEFAULT_LIMIT = 50
          MAX_LIMIT = 100
          ALLOWED_SCOPES = %w[inbox archived].freeze

          def call(params)
            limit = integer(params[:limit], default: DEFAULT_LIMIT, minimum: 1, maximum: MAX_LIMIT)
            return failure(errors: { message: "invalid_limit" }) if limit.nil?

            offset = integer(params[:offset], default: 0, minimum: 0)
            return failure(errors: { message: "invalid_offset" }) if offset.nil?

            scope = params[:scope].presence || "inbox"
            return failure(errors: { message: "invalid_scope" }) unless scope.is_a?(String) && ALLOWED_SCOPES.include?(scope.strip)

            success(Input.new(limit:, offset:, scope: scope.strip))
          end

          private

          def integer(raw, default:, minimum:, maximum: nil)
            return default if raw.nil? || raw.is_a?(String) && raw.strip.empty?

            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A-?\d+\z/.match?(raw.strip))
            return if value.nil? || value < minimum || maximum && value > maximum

            value
          rescue ArgumentError
            nil
          end
        end

        class ConversationDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:key, :scope, :around, :before_id, :after_id, :limit)
          ALLOWED_SCOPES = %w[inbox archived].freeze
          OLDEST_UNREAD = "oldest_unread"

          def call(params)
            key = params[:key]
            key = key.strip if key.is_a?(String)
            return failure(errors: { message: "invalid_key" }) if !key.is_a?(String) || key.empty?

            scope = params[:scope].presence || "inbox"
            return failure(errors: { message: "invalid_scope" }) unless scope.is_a?(String) && ALLOWED_SCOPES.include?(scope.strip)

            around = present_param(params[:around])
            before_id = present_param(params[:before])
            after_id = present_param(params[:after])
            modes = [around, before_id, after_id].count { |value| !value.nil? }
            return failure(errors: { message: "invalid_window" }) if modes > 1

            if modes.zero?
              return failure(errors: { message: "invalid_limit" }) if present_param(params[:limit])

              return success(Input.new(key:, scope: scope.strip, around: nil, before_id: nil, after_id: nil, limit: nil))
            end

            parsed_around = nil
            parsed_before = nil
            parsed_after = nil
            if around
              parsed_around = parse_around(around)
              return failure(errors: { message: "invalid_around" }) if parsed_around.nil?
            elsif before_id
              parsed_before = positive_integer(before_id)
              return failure(errors: { message: "invalid_cursor" }) if parsed_before.nil?
            else
              parsed_after = positive_integer(after_id)
              return failure(errors: { message: "invalid_cursor" }) if parsed_after.nil?
            end

            limit = window_limit(params[:limit])
            return failure(errors: { message: "invalid_limit" }) if limit.nil?

            success(Input.new(
              key:,
              scope: scope.strip,
              around: parsed_around,
              before_id: parsed_before,
              after_id: parsed_after,
              limit:,
            ))
          end

          private

          def present_param(raw)
            return if raw.nil?
            return if raw.is_a?(String) && raw.strip.empty?

            raw
          end

          def parse_around(raw)
            value = raw.is_a?(String) ? raw.strip : raw
            return OLDEST_UNREAD if value == OLDEST_UNREAD

            positive_integer(value)
          end

          def window_limit(raw)
            return CommandTower::Messaging::Inbox::Reader::WINDOW_LIMIT unless present_param(raw)

            value = positive_integer(raw)
            return if value.nil? || value > CommandTower::Messaging::Inbox::Reader::WINDOW_LIMIT

            value
          end

          def positive_integer(raw)
            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A\d+\z/.match?(raw.strip))
            value if value&.positive?
          rescue ArgumentError
            nil
          end
        end

        class ShowDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:inbox_item_id)

          def call(params)
            value = positive_integer(params[:id])
            return failure(errors: { message: "invalid_inbox_item_id" }) unless value

            success(Input.new(inbox_item_id: value))
          end

          private

          def positive_integer(raw)
            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A\d+\z/.match?(raw.strip))
            value if value&.positive?
          rescue ArgumentError
            nil
          end
        end

        class BulkIdsDeserializer < ShowDeserializer
          Input = Data.define(:inbox_item_ids)
          MAX_IDS = 100

          def call(params)
            raw = params[:ids]
            return failure(errors: { message: "invalid_ids" }) unless raw.is_a?(Array) && raw.any? && raw.size <= MAX_IDS

            values = raw.map { |entry| positive_integer(entry) }
            return failure(errors: { message: "invalid_ids" }) if values.any?(&:nil?)

            success(Input.new(inbox_item_ids: values.uniq))
          end
        end
      end
    end
  end
end
