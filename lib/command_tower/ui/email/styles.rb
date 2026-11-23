# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      # Email palette contract and tint maths. Spec: design ux/states.md
      # sections 5.C and 8 (E1, E2).
      module Styles
        PALETTE_KEYS = %w[
          background card border primary primaryForeground foreground textPrimary
          textSecondary muted mutedForeground success warning danger
        ].freeze
        HEX_COLOR = /\A#\h{6}\z/

        class << self
          # Returns a frozen copy with string keys. Rejects missing or extra
          # keys and any value that is not `#RRGGBB`. Messages name keys, never values.
          def validate_palette!(palette)
            raise InvalidTokenError, "palette must be a Hash" unless palette.is_a?(Hash)

            normalized = palette.transform_keys(&:to_s)
            reject_keys!(normalized)
            bad = normalized.reject { |_key, value| value.is_a?(String) && HEX_COLOR.match?(value) }.keys
            raise InvalidTokenError, "palette values must be #RRGGBB: #{bad.join(', ')}" if bad.any?

            normalized.freeze
          end

          # Pre-blended tint for a tone on `palette.card`: { background:, border: }.
          # Neutral uses `muted` at the neutral alpha and the `border` colour at 1.0.
          def tint(tone, palette)
            palette = validate_palette!(palette)
            mapping = Tokens.mapping
            color = palette.fetch(Tokens.tone_palette_key(tone))
            card = palette.fetch("card")
            return neutral_tint(color, card, palette, mapping) if tone.to_s == "neutral"

            {
              background: blend(color, card, mapping.fetch("tintBackgroundAlpha")),
              border: blend(color, card, mapping.fetch("tintBorderAlpha"))
            }
          end

          # Blends `foreground` over `base` at `alpha`, per 8-bit channel, half-up
          # rounding with exact Rational arithmetic (Float misrounds exact halves).
          def blend(foreground, base, alpha)
            exact_alpha = alpha.to_s.to_r # "0.1".to_r is 1/10; Float#to_r is not
            hex = channels(foreground).zip(channels(base)).map do |fg, bg|
              format("%02X", (bg + ((fg - bg) * exact_alpha) + Rational(1, 2)).floor)
            end
            "##{hex.join}"
          end

          private

          def neutral_tint(color, card, palette, mapping)
            {
              background: blend(color, card, mapping.fetch("neutralTintBackgroundAlpha")),
              border: palette.fetch(mapping.fetch("neutralTintBorder"))
            }
          end

          def reject_keys!(normalized)
            missing = PALETTE_KEYS - normalized.keys
            extra = normalized.keys - PALETTE_KEYS
            raise InvalidTokenError, "palette missing keys: #{missing.join(', ')}" if missing.any?
            raise InvalidTokenError, "palette has unknown keys: #{extra.join(', ')}" if extra.any?
          end

          def channels(hex)
            hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) }
          end
        end
      end
    end
  end
end
