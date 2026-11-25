# frozen_string_literal: true

namespace :command_tower do
  namespace :home_notices do
    desc "Delete ended home notice rows idle for 180 days (hosts schedule this daily)"
    task prune: :environment do
      CommandTower::HomeNotices::PruneEndedJob.perform_now
      puts "home notices pruned"
    end
  end
end
