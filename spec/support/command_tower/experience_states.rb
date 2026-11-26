# frozen_string_literal: true

module CommandTower
  module ExperienceStatesSpecHelper
    def reset_host_experience_states!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.experience_states.reset_host_definitions!
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::ExperienceStatesSpecHelper
  config.after { reset_host_experience_states! }
end
