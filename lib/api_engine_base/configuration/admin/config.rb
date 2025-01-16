# frozen_string_literal: true

require "class_composer"

module ApiEngineBase
  module Configuration
    module Admin
      class Config
        include ClassComposer::Generator

        add_composer :enable,
          desc: "Allow Admin Capabilities for the application. By default, this is enabled",
          allowed: [FalseClass, TrueClass],
          default: true
      end
    end
  end
end
