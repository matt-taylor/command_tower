# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      class Banner < Node
        TYPE = "banner"

        field :tone, :string, default: "neutral"
        field :title, :string
        include Spanned

        validates :tone, inclusion: { in: Tokens::TONE }
      end
    end
  end
end
