# frozen_string_literal: true

require "json"
require "tzinfo"

module CommandTower
  module UI
    # Time-zone label rule for server-rendered times (design section 3.2, states section 8 C).
    #
    # Rule, evaluated over the window 1 Jan of the generation year to 31 Dec of the next year:
    #   1. The zone observes DST in the window and its standard/daylight abbreviations are
    #      alphabetic `<P>ST` / `<P>DT`: label is `<P>T` (PST/PDT -> PT).
    #   2. No DST in the window, a single alphabetic abbreviation that maps to one UTC offset
    #      across all zones (unambiguous): the abbreviation as is (HST, MST in Phoenix, UTC).
    #   3. Anything else: `GMT` for a zero offset, otherwise `GMT+h[:mm]` / `GMT-h[:mm]` at the instant.
    #
    # Rules 1 and 2 are generated into the token mapping (`zoneAbbreviations`, a zone id to label
    # map); rule 3 zones are absent from it and are labelled from the offset at the instant.
    # Historical DST does not count. Generate with `rake command_tower:ui:zone_abbreviations`.
    module ZoneAbbreviation
      MAPPING_PATH = File.expand_path("tokens/ui_token_mapping.json", __dir__)
      GENERATED_KEYS = %w[zoneAbbreviations ambiguousAbbreviations tzdataVersion].freeze
      ALPHABETIC = /\A[A-Z]+\z/
      STANDARD = /\A([A-Z]+)ST\z/
      FALLBACK_ZONEINFO_DIR = "/usr/share/zoneinfo"

      class << self
        # Label for `zone_id` at the UTC instant `at` (Time), using the generated mapping.
        def label(zone_id, at, mapping: nil)
          mapping ||= JSON.parse(File.read(MAPPING_PATH)).fetch("zoneAbbreviations")
          mapping.fetch(zone_id) { gmt_label(TZInfo::Timezone.get(zone_id).period_for_utc(at.utc).offset) }
        end

        # `GMT`, `GMT+5:30`, `GMT-3` from a TZInfo offset.
        def gmt_label(offset)
          total = offset.observed_utc_offset
          return "GMT" if total.zero?

          minutes = total.abs / 60
          hours, rest = minutes.divmod(60)
          minutes_part = rest.zero? ? nil : format(":%02d", rest)
          "GMT#{total.negative? ? '-' : '+'}#{hours}#{minutes_part}"
        end

        # The three generated keys for a generation year.
        def generate(year: Time.now.utc.year)
          zones = window_offsets(year)
          ambiguous = ambiguous_abbreviations(zones)
          labels = zones.to_h { |zone_id, offsets| [zone_id, fixed_label(offsets, ambiguous)] }.compact

          { "zoneAbbreviations" => labels.sort.to_h, "ambiguousAbbreviations" => ambiguous.sort,
            "tzdataVersion" => tzdata_version }
        end

        # Splices the generated keys into the mapping JSON as its last three keys and leaves
        # every other byte of the file alone. Deterministic: same year and tzdata, same bytes.
        def write!(year: Time.now.utc.year, path: MAPPING_PATH)
          generated = generate(year: year)
          text = File.read(path)
          generated_block = /,\n  "zoneAbbreviations":.*\z/m
          head = text.match?(generated_block) ? text.sub(generated_block, "") : text.sub(/\s*\}\s*\z/, "")
          File.write(path, "#{head},\n#{render(generated)}\n}\n")
          generated
        end

        def tzdata_version
          source = TZInfo::DataSource.get
          dir = source.respond_to?(:zoneinfo_dir) ? source.zoneinfo_dir : FALLBACK_ZONEINFO_DIR
          line = File.foreach(File.join(dir, "tzdata.zi")).first.to_s
          line[/\A#\s*version\s+(\S+)/, 1] || raise("tzdata.zi has no version line")
        end

        private

        # zone id => offsets (TZInfo::TimezoneOffset) in effect during the window.
        def window_offsets(year)
          from = Time.utc(year, 1, 1)
          to = Time.utc(year + 2, 1, 1)
          TZInfo::Timezone.all_identifiers.to_h do |zone_id|
            zone = TZInfo::Timezone.get(zone_id)
            offsets = [zone.period_for_utc(from).offset] + zone.transitions_up_to(to, from).map(&:offset)
            [zone_id, offsets.uniq]
          end
        end

        # Alphabetic abbreviations that map to more than one UTC offset across zones.
        def ambiguous_abbreviations(zones)
          seen = Hash.new { |hash, key| hash[key] = [] }
          zones.each_value do |offsets|
            offsets.each do |offset|
              abbreviation = offset.abbreviation.to_s
              seen[abbreviation] << offset.observed_utc_offset if abbreviation.match?(ALPHABETIC)
            end
          end
          seen.select { |_, utc_offsets| utc_offsets.uniq.size > 1 }.keys
        end

        def fixed_label(offsets, ambiguous)
          daylight, standard = offsets.partition(&:dst?)
          return daylight_label(standard, daylight) if daylight.any?

          fixed_standard_label(standard.map(&:abbreviation).uniq, ambiguous)
        end

        def fixed_standard_label(abbreviations, ambiguous)
          only = abbreviations.first
          only if abbreviations.one? && only.match?(ALPHABETIC) && ambiguous.exclude?(only)
        end

        def daylight_label(standard, daylight)
          standard_abbreviations = standard.map(&:abbreviation).uniq
          daylight_abbreviations = daylight.map(&:abbreviation).uniq
          return unless standard_abbreviations.one? && daylight_abbreviations.one?

          prefix = standard_abbreviations.first[STANDARD, 1]
          "#{prefix}T" if prefix && daylight_abbreviations.first == "#{prefix}DT"
        end

        def render(generated)
          zones = generated.fetch("zoneAbbreviations").map { |id, label| "    #{id.to_json}: #{label.to_json}" }
          [
            %(  "zoneAbbreviations": {\n#{zones.join(",\n")}\n  },),
            %(  "ambiguousAbbreviations": #{generated.fetch('ambiguousAbbreviations').to_json},),
            %(  "tzdataVersion": #{generated.fetch('tzdataVersion').to_json})
          ].join("\n")
        end
      end
    end
  end
end
