# frozen_string_literal: true

module CommandTower
  module UI
    module Fragments
      # One labelled fact: a `key_value` with a single item. `value` is a String.
      class FactRow < Fragment
        attribute :value, :string
        attribute :label, :string
        attribute :icon, :string

        validates :value, presence: true

        def compose(builder)
          builder.key_value { |kv| kv.item(label.presence, value, icon: icon.presence) }
        end
      end
    end
  end
end
