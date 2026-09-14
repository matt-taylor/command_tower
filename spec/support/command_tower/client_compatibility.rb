# frozen_string_literal: true

module CommandTower
  module ClientCompatibilitySpecHelper
    DUMMY_WEB_MINIMUM = "1.0.0"
    DUMMY_WEB_RECOMMENDED = "1.0.0"

    def reset_client_compatibility!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.client_compatibility.reset_host_definitions!
      restore_dummy_client_compatibility_web_floor!
    end

    def restore_dummy_client_compatibility_web_floor!
      registry = CommandTower.config.registry.client_compatibility
      return unless registry.configured_platforms.empty?

      registry.mode = :observe
      registry.platform(:web) do |platform|
        platform.minimum = DUMMY_WEB_MINIMUM
        platform.recommended = DUMMY_WEB_RECOMMENDED
      end
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::ClientCompatibilitySpecHelper
  config.before { restore_dummy_client_compatibility_web_floor! }
  config.after { reset_client_compatibility! }
end
