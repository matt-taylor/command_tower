# frozen_string_literal: true

namespace :command_tower do
  namespace :home_notices do
    desc "Write the home notice response fixtures under spec/fixtures/home_notices"
    task fixtures: :environment do
      require Rails.root.join("lib/home_notice_fixtures").to_s

      count = HomeNoticeFixtures.write_all!
      puts "Wrote #{count} home notice fixtures under #{HomeNoticeFixtures::DIR}"
    end
  end
end
