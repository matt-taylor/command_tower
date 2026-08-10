# frozen_string_literal: true

module CommandTower
  module ProtectedFixtureControllerRoutes
    extend ActiveSupport::Concern

    included do
      routes { CommandTower::Engine.routes }
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::ProtectedFixtureControllerRoutes,
                 type: :controller,
                 protected_fixture: true
end
