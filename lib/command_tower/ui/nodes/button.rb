# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # A document holds at most one `primary` button (enforced by Document).
      class Button < Node
        TYPE = "button"

        field :label, :string
        field :variant, :string, default: "secondary"
        field :action

        validates :label, presence: true
        validates :variant, inclusion: { in: Tokens::BUTTON_VARIANT }
        validate :action_is_navigate

        def primary?
          variant == "primary"
        end

        def each_child
          yield "action", action if action.is_a?(Base)
        end

        private

        def action_is_navigate
          errors.add(:action, :invalid_action) unless action.is_a?(Action::Navigate)
        end
      end
    end
  end
end
