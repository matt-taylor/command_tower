# frozen_string_literal: true

FactoryBot.define do
  factory :authorization_entity, class: CommandTower::Authorization::Entity do
    controller { Class.new(::CommandTower::ApplicationController) }
    sequence(:name) { |n| "entity_#{n}" }

    transient do
      additional_method_count { 5 }
      additional_methods { [] }
      method_name { "action_#{SecureRandom.hex(3)}" }
    end

    trait :only do
      only { method_name }
    end

    trait :except do
      except { method_name }
    end

    trait :additional_methods do
      additional_methods do
        Array.new(additional_method_count) { |i| "extra_#{i}_#{SecureRandom.hex(2)}" }
      end
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
