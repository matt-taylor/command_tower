# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module SignupSession
      class EmailAvailability < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :enable,
          desc: "Expose GET /auth/email/availability on Engine.routes when enabled",
          allowed: [FalseClass, TrueClass],
          default: true
      end
    end
  end
end
