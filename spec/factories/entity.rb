# frozen_string_literal: true

FactoryBot.define do
  factory :entity, class: CommandTower::Authorization::Entity do
    controller { Class.new(::CommandTower::ApplicationController) }
    name { Faker::Lorem.unique.word }

    transient do
      additional_method_count { 5 }
      additional_methods { [] }
      method_name { Faker::Lorem.unique.word }
    end

    trait :only do
      only { method_name }
    end

    trait :except do
      except { method_name }
    end

    trait :additional_methods do
      additional_methods { Faker::Lorem.unique.words(number: additional_method_count) }
    end

    initialize_with do
      methods = (defined?(only) ? Array(only) : []) + (defined?(except) ? Array(except) : []) + additional_methods
      methods.compact.each do |meth|
        controller.define_method(meth) {}
      end

      new(**attributes)
    end
  end
end
