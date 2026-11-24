# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Compliance < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :api_base_url,
                     desc: "Public API origin used to build the one-click unsubscribe URL (no trailing slash, " \
                           "no /api). Defaults to ENV COMMAND_TOWER_API_BASE_URL when set, else nil " \
                           "(unsubscribe headers are omitted).",
                     allowed: [String, NilClass],
                     default: nil,
                     default_shown: 'ENV["COMMAND_TOWER_API_BASE_URL"]'

        add_composer :preferences_path,
                     desc: "Host path of the notification preferences page, appended to " \
                           "config.application.composed_url in the email footer. " \
                           "Default nil (footer links to composed_url).",
                     allowed: [String, NilClass],
                     default: nil

        add_composer :postal_address,
                     desc: "Physical postal address printed in the footer of promotional email. Required for any " \
                           "promotional MessageDefinition. Default nil.",
                     allowed: [String, NilClass],
                     default: nil

        add_composer :unsubscribe_secret,
                     desc: "Optional secret overriding the key derived from secret_key_base for unsubscribe " \
                           "tokens. Never log. Default nil.",
                     allowed: [String, NilClass],
                     default: nil

        # The ENV fallback is read at call time so it is not frozen at load.
        alias configured_api_base_url api_base_url

        def api_base_url
          configured_api_base_url.presence || ENV["COMMAND_TOWER_API_BASE_URL"].presence
        end
      end
    end
  end
end
