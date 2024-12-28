# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    password { Faker::Alphanumeric.alpha(number: 20) }
    password_confirmation { password }
    email_validated { true }
    email { Faker::Internet.email }
    username do
      min = ApiEngineBase.config.username.username_length_min
      max = ApiEngineBase.config.username.username_length_max

      Faker::Lorem.characters(number: rand(min...max))
    end

    created_at { Time.now }

    trait :unvalidated_email do
      email_validated { false }
    end

    trait :verifier_token do
      verifier_token { SecureRandom.alphanumeric(32) }
    end
  end
end
