# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Vertical stack (the catalog has no row or direction, UX decision G1).
      #
      # `align` (UX decision G3):
      #   absent  = stretch children across the cross axis
      #   start / center / end = cross-axis alignment
      #   between = main-axis space-between
      # `badge` and `avatar` children always hug their content.
      class Stack < Container
        TYPE = "stack"

        field :gap, :string, default: "md"
        field :align, :string

        validates :gap, inclusion: { in: Tokens::GAP }
        validates :align, inclusion: { in: Tokens::ALIGN }, allow_nil: true
      end
    end
  end
end
