# frozen_string_literal: true

FactoryBot.define do
  factory :role, class: CommandTower::Authorization::Role do
    name { Faker::Lorem.word }
    allow_everything { false }
    description { Faker::Lorem.sentence }
    entities { build_list(:entity, rand(1..10)) }

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
