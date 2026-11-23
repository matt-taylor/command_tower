# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # `textTone` accepts only primary, secondary, muted and accent (council
      # A2): success, warning and danger fail contrast as text and stay tone
      # tokens for badges, tiles, banners and cards.
      class Text < Node
        TYPE = "text"

        field :variant, :string, default: "body"
        field :text_tone, :string, default: "primary"
        field :max_lines, :integer
        include Spanned

        validates :variant, inclusion: { in: Tokens::VARIANT }
        validates :text_tone, inclusion: { in: Tokens::TEXT_TONE }
        validates :max_lines, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 },
                              allow_nil: true
      end
    end
  end
end
