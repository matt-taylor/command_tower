# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # ActiveModel type for `items`: hashes become KeyValue::Item.
      class KeyValueItemListType < ActiveModel::Type::Value
        private

        def cast_value(value)
          return value unless value.is_a?(Array)

          value.map { |item| item.is_a?(Hash) ? KeyValue::Item.new(item) : item }
        end
      end

      # Label/value rows. Needs at least one item (UX decision G7).
      class KeyValue < Node
        TYPE = "key_value"

        # One row. `value` is a String or an Instant node.
        class Item < Base
          field :icon, :string
          field :label, :string
          field :value

          validates :icon, format: { with: ICON_FORMAT }, allow_nil: true
          validate :value_is_text_or_instant

          def each_child
            yield "value", value if value.is_a?(Instant)
          end

          private

          def value_is_text_or_instant
            return errors.add(:value, :blank) if value.nil? || value == ""
            return if value.is_a?(String) || value.is_a?(Instant)

            errors.add(:value, :invalid)
          end
        end

        field :items, KeyValueItemListType.new, default: -> { [] }

        validate :items_are_valid_list

        def each_child(&)
          nested_objects("items", items, &)
        end

        private

        def items_are_valid_list
          return errors.add(:items, :invalid_child) unless items.is_a?(Array) && items.all?(Item)

          errors.add(:items, :blank) if items.empty?
          errors.add(:items, :too_many_items) if items.length > Limits::MAX_KEY_VALUE_ITEMS
        end
      end
    end
  end
end
