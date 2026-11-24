# frozen_string_literal: true

require "time"
require "tzinfo"

module CommandTower
  module UI
    # Server-side rendering of an instant for a zone (design section 3.2, states section 5.I).
    #
    # en-US, 12-hour clock, no leading zeros, uppercase AM/PM, plain U+0020 separators.
    # `:countdown` is app-only; the server renders it as `:short`. `:date` is never labelled.
    # Label `:auto` is always shown on the server. The label comes from {ZoneAbbreviation}.
    module TimeFormatter
      PATTERNS = {
        short: "%a, %b %-d, %-l:%M %p",
        long: "%A, %B %-d, %Y at %-l:%M %p",
        date: "%a, %b %-d",
        time: "%-l:%M %p"
      }.freeze
      FORMATS = (PATTERNS.keys + [:countdown]).freeze
      LABELS = %i[auto always never].freeze
      USER_ZONE = "user"

      class << self
        # `at` is a Time or a UTC ISO-8601 string; `zone` a TZInfo identifier, or
        # `:user` / "user", which resolves to `user_zone` (default `config.ui.default_zone`).
        def call(at:, zone:, format:, label: :auto, user_zone: CommandTower.config.ui.default_zone)
          format = pick(format, FORMATS, "format")
          label = pick(label, LABELS, "label")
          instant = parse(at)
          timezone = TZInfo::Timezone.get(zone.to_s == USER_ZONE ? user_zone.to_s : zone.to_s)
          text = timezone.to_local(instant).strftime(PATTERNS.fetch(format == :countdown ? :short : format))
          return text unless show_label?(format, label)

          "#{text} #{ZoneAbbreviation.label(timezone.identifier, instant, mapping: abbreviations)}"
        end

        private

        def pick(value, allowed, name)
          symbol = value.to_sym
          allowed.include?(symbol) ? symbol : raise(ArgumentError, "unknown time #{name}")
        end

        def show_label?(format, label)
          return false if format == :date

          label != :never
        end

        def abbreviations
          Tokens.mapping.fetch("zoneAbbreviations")
        end

        def parse(at)
          (at.is_a?(String) ? Time.iso8601(at) : at).utc
        end
      end
    end
  end
end
