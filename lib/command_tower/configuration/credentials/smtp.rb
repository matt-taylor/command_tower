# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Credentials
      # Explicit SMTP deployment credentials (config.credentials.smtp).
      # Consumed by CredentialResolution — not provider behavior configuration.
      class Smtp < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :user_name,
          desc: "SMTP username. Explicit supply for Credential Resolution under config.credentials.smtp. Also used as Messaging ChannelMailer From when present. Alternatives: custom credential_resolver or GMAIL_USER_NAME ENV.",
          allowed: String,
          default: "",
          default_shown: '""'

        add_composer :password,
          desc: "SMTP password. Explicit supply for Credential Resolution under config.credentials.smtp. Alternatives: custom credential_resolver or GMAIL_PASSWORD ENV.",
          allowed: String,
          default: "",
          default_shown: '""'

        def inspect
          "#<#{self.class.name} user_name=[REDACTED] password=[REDACTED]>"
        end

        alias_method :pretty_inspect, :inspect
      end
    end
  end
end
