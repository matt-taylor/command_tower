# frozen_string_literal: true

namespace :command_tower do
  namespace :messaging do
    desc "Write the message fixtures: inbox documents, email parts and gallery payloads under spec/fixtures"
    task fixtures: :environment do
      require Rails.root.join("lib/messaging_fixtures").to_s

      MessagingFixtures.write_all
      puts "Wrote #{MessagingFixtures.files.length} message fixtures under #{MessagingFixtures::ROOT}"
    end
  end
end
