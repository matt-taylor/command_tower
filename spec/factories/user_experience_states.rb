# frozen_string_literal: true

FactoryBot.define do
  factory :user_experience_state, class: "CommandTower::UserExperienceState" do
    user
    host_key { "command_tower" }
    experience_key { "welcome" }
    scope_type { "example_scope" }
    sequence(:scope_identifier) { |n| n.to_s }
    version { "v1" }
    completed_at { Time.current }
  end
end
