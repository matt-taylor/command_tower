# frozen_string_literal: true

require "api_engine_base/schema"

module ApiEngineBase
  class Engine < ::Rails::Engine
    isolate_namespace ApiEngineBase

    # Run after Rails loads the initializes and environment files
    # Ensures User has already set their desired config before we lock this down
    initializer "api_engine_base.config.instantiate", after: :load_config_initializers do |_app|
      # ensure defaults are instantiated and all variables are assigned
      ApiEngineBase.config.class_composer_assign_defaults!(children: true)

      unless Rails.env.test?
        # Now that we can confirm all variables are defined, freeze all objects an their children
        ApiEngineBase.config.class_composer_freeze_objects!(behavior: :raise, children: true)
      end
    end
  end
end
