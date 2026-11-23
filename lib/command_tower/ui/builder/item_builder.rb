# frozen_string_literal: true

module CommandTower
  module UI
    class Builder
      # Collects `key_value` rows. `time` returns an Instant for use as a row
      # value instead of adding it as a child.
      class ItemBuilder
        attr_reader :items

        def initialize(builder, path)
          @builder = builder
          @path = path
          @items = []
        end

        def item(label, value, icon: nil)
          @items << { icon:, label:, value: }.compact
        end

        def time(**)
          @builder.build_time("#{@path}.items[#{@items.length}].value", **)
        end
      end
    end
  end
end
