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
