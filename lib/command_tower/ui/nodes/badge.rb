# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      class Badge < Node
        TYPE = "badge"

        field :label, :string
        field :tone, :string, default: "neutral"

        validates :label, presence: true
        validates :tone, inclusion: { in: Tokens::TONE }
      end
    end
  end
end
