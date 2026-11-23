# frozen_string_literal: true

module CommandTower
  module UI
    module Fragments
      # Stacked buttons: the primary first, then up to two secondaries.
      # `buttons` is a list of `{ label:, action:, variant: }` symbol-key hashes; `variant`
      # defaults to `secondary`, and `ghost` is used only when a caller asks.
      #
      #   d.fragment(CtaGroup, buttons: [
      #     { label: "View classes", action: d.navigate(path: "/classes"), variant: :primary },
      #     { label: "Details", action: d.navigate(path: "/details") }
      #   ])
      class CtaGroup < Fragment
        MAX_SECONDARIES = 2

        attribute :buttons, default: -> { [] }

        validate :buttons_are_valid

        def compose(builder)
          builder.stack(gap: :sm) do |s|
            primaries.each { |button| emit(s, button) }
            secondaries.each { |button| emit(s, button) }
          end
        end

        private

        def variant_of(button)
          (button[:variant] || :secondary).to_s
        end

        def primaries
          buttons.select { |button| variant_of(button) == "primary" }
        end

        def secondaries
          buttons.reject { |button| variant_of(button) == "primary" }
        end

        def emit(builder, button)
          builder.button(button.fetch(:label), action: button.fetch(:action), variant: variant_of(button))
        end

        def buttons_are_valid
          return errors.add(:buttons, :invalid) unless well_formed?

          errors.add(:buttons, :too_many_primaries) if primaries.length > 1
          errors.add(:buttons, :too_many_secondaries) if secondaries.length > MAX_SECONDARIES
        end

        def well_formed?
          buttons.is_a?(Array) && buttons.any? &&
            buttons.all? { |button| button.is_a?(Hash) && button.key?(:label) && button.key?(:action) }
        end
      end
    end
  end
end
