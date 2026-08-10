# frozen_string_literal: true

FactoryBot.define do
  factory :authorization_role, class: CommandTower::Authorization::Role do
    name { "role_#{SecureRandom.hex(4)}" }
    allow_everything { false }
    description { "Authorization role for tests" }
    entities { build_list(:authorization_entity, 2) }

    trait :allow_everything do
      allow_everything { true }
      entities { [] }
    end

    trait :with_create_role do
      transient do
        with_create_role { true }
      end
    end

    initialize_with do
      if defined?(with_create_role)
        CommandTower::Authorization::Role.create_role(**attributes)
      else
        new(**attributes)
      end
    end
  end
end
