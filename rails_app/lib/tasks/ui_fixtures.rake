# frozen_string_literal: true

namespace :command_tower do
  namespace :ui do
    desc "Write the UI document fixtures to spec/fixtures/ui/documents/<key>.json"
    task fixtures: :environment do
      require Rails.root.join("lib/ui_fixtures").to_s

      UiFixtures.write_all
      puts "Wrote #{UiFixtures.keys.length} fixtures to #{UiFixtures::OUTPUT_DIR}"
    end
  end
end
