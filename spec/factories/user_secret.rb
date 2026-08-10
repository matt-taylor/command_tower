# frozen_string_literal: true

FactoryBot.define do
  factory :user_secret, class: "UserSecret" do
    user
    reason { CommandTower::Secrets::EMAIL_VERIFICIATION.to_s }
    sequence(:secret) { |n| "secret-#{n}-#{SecureRandom.hex(8)}" }
    death_time { 1.hour.from_now }
    use_count { 0 }
    use_count_max { 5 }
  end
end
