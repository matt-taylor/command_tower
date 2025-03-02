# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Application
      class Config
        include ClassComposer::Generator

        add_composer :app_name,
          allowed: String,
          dynamic_default:  ->(_) { CommandTower.default_app_name },
          desc: "The default name of the application",
          default_shown: "# Auto Populates to the name of the application"

        add_composer :communication_name,
          allowed: String,
          dynamic_default: :app_name,
          desc: "The name of the application to use in communications like SMS or Email"

        add_composer :url,
          allowed: String,
          default: ENV.fetch("command_tower_URL", "http://localhost"),
          desc: "When composing SSO's or verification URL's, this is the URL for the application"

        add_composer :port,
          allowed: [String, NilClass],
          default: ENV.fetch("command_tower_PORT", nil),
          desc: "When composing SSO's or verification URL's, this is the PORT for the application"

        add_composer :composed_url,
          allowed: String,
          dynamic_default: ->(instance) { "#{instance.url}#{ ":#{instance.port}" if instance.port }" },
          desc: "The fully composed URL including the port number when needed. This Config variable is not needed as it is composed of the `url` and `port` composed values",
          default_shown: "# Composed String of the URL and PORT. Override this with caution"
      end
    end
  end
end
