# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/identity/phone_verification"

module CommandTower
  module Configuration
    module Identity
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :phone_verification,
          desc: "Identity phone verification OTP configuration",
          allowed: PhoneVerification,
          default: PhoneVerification.new
      end
    end
  end
end
