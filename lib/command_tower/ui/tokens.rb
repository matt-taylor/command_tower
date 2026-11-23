# frozen_string_literal: true

require "json"

module CommandTower
  module UI
    # Token enums and the shared design mapping (spacing px, type steps, tone
    # palette keys, tint alphas). The mapping JSON is runtime data, parsed once
    # and deep-frozen. Spec: design ux/states.md section 5.
    module Tokens
      MAPPING_PATH = File.expand_path("tokens/ui_token_mapping.json", __dir__)

      GAP = %w[none xs sm md lg xl].freeze
      TONE = %w[neutral accent success warning danger].freeze
      # Only these four text tones are allowed (council A2): warning/success/danger fail contrast as text.
      TEXT_TONE = %w[primary secondary muted accent].freeze
      VARIANT = %w[display heading_xl heading_l heading_m title subtitle body caption overline mono].freeze
      SURFACE = %w[raised tinted plain].freeze
      ALIGN = %w[start center end between].freeze
      AVATAR_SIZE = %w[sm md lg].freeze
      BUTTON_VARIANT = %w[primary secondary ghost].freeze

      class << self
        def mapping
          @mapping ||= deep_freeze(JSON.parse(File.read(MAPPING_PATH)))
        end

        def spacing_px(token)
          mapping.fetch("spacing").fetch(token.to_s) { raise InvalidTokenError, "unknown spacing token" }
        end

        def type_step(variant)
          mapping.fetch("typeSteps").fetch(variant.to_s) { raise InvalidTokenError, "unknown type variant" }
        end

        def tone_palette_key(tone)
          mapping.fetch("tones").fetch(tone.to_s) { raise InvalidTokenError, "unknown tone" }.fetch("paletteKey")
        end

        def avatar_px(size)
          mapping.fetch("avatarSizes").fetch(size.to_s) { raise InvalidTokenError, "unknown avatar size" }
        end

        private

        def deep_freeze(value)
          case value
          when Hash then value.each { |k, v| k.freeze && deep_freeze(v) }
          when Array then value.each { |v| deep_freeze(v) }
          end
          value.freeze
        end
      end
    end
  end
end
