# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      class StatTile < Node
        TYPE = "stat_tile"

        field :value, :string
        field :label, :string
        field :tone, :string
        field :icon, :string

        validates :value, :label, presence: true
        validates :tone, inclusion: { in: Tokens::TONE }, allow_nil: true
        validates :icon, format: { with: ICON_FORMAT }, allow_nil: true
      end
    end
  end
end
