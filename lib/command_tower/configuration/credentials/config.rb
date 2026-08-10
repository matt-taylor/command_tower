# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/credentials/twilio"
require "command_tower/configuration/credentials/smtp"

module CommandTower
  module Configuration
    module Credentials
      # Deployment provider credentials namespace (typed per provider).
      # Each provider owns its own credential object — no shared generic fields.
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :twilio,
          desc: "Twilio deployment credentials (account_sid, auth_token). Typed per provider; consumed by Credential Resolution.",
          allowed: Twilio,
          default: Twilio.new

        add_composer :smtp,
          desc: "SMTP deployment credentials (user_name, password). Typed per provider; consumed by Credential Resolution.",
          allowed: Smtp,
          default: Smtp.new

        def inspect
          "#<#{self.class.name} twilio=[REDACTED] smtp=[REDACTED]>"
        end

        alias_method :pretty_inspect, :inspect
      end
    end
  end
end
