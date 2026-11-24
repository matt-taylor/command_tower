# frozen_string_literal: true

module CommandTower
  module EmailTheme
    # Resolves the 13-key palette the email renderer takes (design D19).
    #
    # Precedence:
    #   1. host `config/ui_tokens.json` (when present)
    #   2. host-customised 9-key `config.email_theme` (legacy adapter; muted,
    #      success, warning and danger come from the CT default)
    #   3. CT default file (`default_ui_tokens.json`)
    module Palette
      KEYS = UI::Email::Styles::PALETTE_KEYS

      # config.email_theme key -> palette key(s) it feeds in the legacy adapter,
      # and the palette key each legacy key is derived from (Resolver).
      LEGACY_TO_PALETTE = {
        canvas_background: "background",
        surface_background: "card",
        surface_border: "border",
        primary_text: "textPrimary",
        body_text: "foreground",
        muted_text: "mutedForeground",
        accent: "primary",
        text_on_accent: "primaryForeground",
        primary_action: "primary"
      }.freeze

      class << self
        # Returns a frozen Hash with exactly the 13 PALETTE_KEYS.
        def resolve(host_path: TokenFile.host_path)
          return pick(TokenFile.load_palette(host_path)) if TokenFile.host_file?(host_path)
          return legacy_palette if legacy_customised?

          default_palette
        end

        def default_palette
          pick(TokenFile.load_palette(TokenFile::DEFAULT_PATH))
        end

        # The 9 legacy keys derived from a palette (Resolver, when a host file exists).
        def legacy_keys_from(palette)
          LEGACY_TO_PALETTE.transform_values { |key| palette.fetch(key) }
        end

        def legacy_customised?
          legacy_keys_from(default_palette) != legacy_theme_values
        end

        private

        def legacy_theme_values
          theme = CommandTower.config.email_theme
          LEGACY_TO_PALETTE.keys.index_with { |key| theme.public_send(key) }
        end

        def legacy_palette
          # `muted_text` feeds both muted-text keys so the secondary text role stays consistent.
          # `accent` and `primary_action` both feed `primary`; only a customised value overrides
          # the default, and `accent` wins when both are customised.
          defaults = legacy_keys_from(default_palette)
          customised = legacy_theme_values.reject { |key, value| value == defaults.fetch(key) }
          overrides = customised.reverse_each.to_h { |key, value| [LEGACY_TO_PALETTE.fetch(key), value] }
          overrides["textSecondary"] = overrides["mutedForeground"] if overrides.key?("mutedForeground")
          pick(default_palette.merge(overrides))
        end

        def pick(palette)
          KEYS.index_with { |key| palette.fetch(key) }.freeze
        end
      end
    end
  end
end
