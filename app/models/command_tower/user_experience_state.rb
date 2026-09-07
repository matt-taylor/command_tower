# frozen_string_literal: true

module CommandTower
  class UserExperienceState < CommandTower::ApplicationRecord
    self.table_name = "user_experience_states"

    belongs_to :user

    validates :host_key, :experience_key, :scope_type, :scope_identifier, :version, presence: true
    validates :experience_key,
              uniqueness: {
                scope: %i[user_id host_key scope_type scope_identifier version],
              }

    scope :for_user_and_host, ->(user:, host_key:) { where(user:, host_key:) }
  end
end
