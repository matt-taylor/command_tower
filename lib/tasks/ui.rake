# frozen_string_literal: true

namespace :command_tower do
  namespace :ui do
    desc "Regenerate zoneAbbreviations, ambiguousAbbreviations and tzdataVersion in ui_token_mapping.json " \
         "(does not boot :environment; needs tzdata). YEAR=2026 pins the generation year."
    task :zone_abbreviations do # rubocop:disable Rails/RakeEnvironment -- deliberately avoids booting the app
      require File.expand_path("../command_tower/ui/zone_abbreviation", __dir__)

      year = ENV.fetch("YEAR") { Time.now.utc.year }.to_i
      generated = CommandTower::UI::ZoneAbbreviation.write!(year: year)
      puts "zone abbreviations: #{generated.fetch('zoneAbbreviations').size} zones, " \
           "#{generated.fetch('ambiguousAbbreviations').size} ambiguous, tzdata #{generated.fetch('tzdataVersion')}"
    end
  end
end
