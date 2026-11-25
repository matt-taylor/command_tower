# frozen_string_literal: true

module CommandTower
  # Persistence only. One row per notice key that an admin has switched on or off.
  class HomeNoticeControl < CommandTower::ApplicationRecord
    self.table_name = "command_tower_home_notice_controls"
    self.primary_key = "key"

    validates :key, presence: true, length: { maximum: 128 }
    validates :enabled, inclusion: { in: [true, false] }
  end
end
