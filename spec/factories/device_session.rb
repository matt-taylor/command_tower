# frozen_string_literal: true

FactoryBot.define do
  factory :device_session, class: "CommandTower::Auth::DeviceSession" do
    association :user
    last_seen_at { Time.current }
    absolute_expires_at { 30.days.from_now }

    trait :revoked do
      revoked_at { Time.current }
      revoked_reason { "logout" }
    end
  end
end
