# frozen_string_literal: true

# Host-style fixtures for the composer, fragment and derived-text specs.
module SampleHostUI
  # A host fragment: one labelled row.
  class FactRow < CommandTower::UI::Fragment
    attribute :label, :string
    attribute :value, :string
    validates :label, :value, presence: true

    def compose(builder)
      builder.key_value { |rows| rows.item label, value }
    end
  end

  # A host composer using a fragment, a time, a button and a secret code.
  class ClassCanceled < CommandTower::UI::Composer
    def compose(builder, starts_at:, room:, code: "424242")
      builder.card do |card|
        card.text "Class ", card.strong("canceled"), variant: :heading_m
        card.fragment FactRow, label: "Where", value: room
        card.key_value { |rows| rows.item "When", rows.time(at: starts_at, zone: "America/Los_Angeles") }
        card.code value: code, label: "Door code", format: :text
        card.button "View classes", action: card.navigate(path: "/classes"), variant: :primary
      end
    end
  end

  # A composer that supplies its own fallback.
  class CustomFallback < CommandTower::UI::Composer
    def compose(builder, **)
      builder.text "Hello"
    end

    def text_fallback(_root, **)
      "Custom"
    end
  end

  # A composer that adds no root node.
  class Empty < CommandTower::UI::Composer
    def compose(_builder, **); end
  end
end
