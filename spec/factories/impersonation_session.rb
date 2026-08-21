# frozen_string_literal: true

FactoryBot.define do
  factory :impersonation_session, class: "CommandTower::Impersonation::Session" do
    association :actor, factory: :user
    association :target, factory: :user
    started_at { Time.current }
    last_activity_at { Time.current }
    idle_expires_at { 10.minutes.from_now }
    absolute_expires_at { 1.hour.from_now }

    trait :ended do
      ended_at { Time.current }
      end_reason { "manual" }
    end
  end
end
