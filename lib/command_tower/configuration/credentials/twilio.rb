# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Credentials
      # Canonical explicit Twilio deployment credentials (config.credentials.twilio).
      # Consumed by CredentialResolution — not provider behavior configuration.
      class Twilio < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :account_sid,
          desc: "Twilio Account SID. Canonical explicit supply for Credential Resolution. Prefer this over ENV when setting credentials in CommandTower.configure.",
          allowed: String,
          default: "",
          default_shown: '""'

        add_composer :auth_token,
          desc: "Twilio Auth Token. Canonical explicit supply for Credential Resolution. Prefer this over ENV when setting credentials in CommandTower.configure.",
          allowed: String,
          default: "",
          default_shown: '""'

        def inspect
          "#<#{self.class.name} account_sid=[REDACTED] auth_token=[REDACTED]>"
        end

        alias_method :pretty_inspect, :inspect
      end
    end
  end
end
