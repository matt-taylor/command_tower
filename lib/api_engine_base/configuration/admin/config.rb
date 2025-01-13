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

        add_composer :application_owners,
          desc: "The number of Owners for the application.",
          allowed: Integer,
          default: 1

        add_composer :privileges,
          desc: "Admin Privileges",
          allowed: Integer,
          default: 1
      end
    end
  end
end
