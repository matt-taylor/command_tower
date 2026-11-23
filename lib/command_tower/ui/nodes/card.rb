# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      class Card < Container
        TYPE = "card"

        field :surface, :string, default: "raised"
        field :tone, :string
        field :padding, :string, default: "md"

        validates :surface, inclusion: { in: Tokens::SURFACE }
        validates :tone, inclusion: { in: Tokens::TONE }, allow_nil: true
        validates :padding, inclusion: { in: Tokens::GAP }
      end
    end
  end
end
