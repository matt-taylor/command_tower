# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}-#{SecureRandom.hex(4)}@example.com" }
    sequence(:username) { |n| "user#{n}#{SecureRandom.hex(3)}" }
    first_name { "Test" }
    last_name { "User" }
    password { "password1234" }
    password_confirmation { password }
    email_validated { true }
    roles { [] }

    trait :unvalidated_email do
      email_validated { false }
    end

    # Alias for hosts that previously used this name (e.g. DoubleFloor Me).
    trait :unverified do
      unvalidated_email
    end

    trait :verifier_token do
      verifier_token { SecureRandom.alphanumeric(32) }
    end

    trait :privileged_roles do
      roles { ["admin", "owner"] }
    end

    trait :admin_roles do
      roles { ["admin"] }
    end

    trait :role_admin do
      roles { ["admin"] }
    end

    trait :role_owner do
      roles { ["owner"] }
    end

    trait :without_phone do
      phone_number { nil }
      phone_number_validated { false }
    end

    trait :with_unverified_phone do
      sequence(:phone_number) { |n| format("+1415555%04d", n % 10_000) }
      phone_number_validated { false }
    end
  end
end
