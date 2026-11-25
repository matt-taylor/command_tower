# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/base"

module CommandTower
  module Configuration
    module HomeNotices
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        MINIMUM_GLOBAL_COOLDOWN = 1.hour

        add_composer :enabled,
                     desc: "Turns Home Notices on. When false the catalog is not loaded and the endpoints return 404.",
                     allowed: [TrueClass, FalseClass],
                     default: false

        add_composer :notices,
                     desc: "Class names (Strings) of Campaign and Delivery subclasses. Checked at boot when enabled.",
                     allowed: Array,
                     default: [],
                     default_shown: "[]"

        add_composer :global_cooldown,
                     desc: "Minimum time between blocking notices for a user. Must be at least 1 hour.",
                     allowed: ActiveSupport::Duration,
                     default: 8.hours,
                     validator: ->(val) { val >= MINIMUM_GLOBAL_COOLDOWN },
                     invalid_message: ->(_val) { "Expected a Duration of at least 1 hour" }

        add_composer :blocking_daily_cap,
                     desc: "Maximum number of blocking notices started per user per day.",
                     allowed: Integer,
                     default: 2

        add_composer :max_open_deliveries,
                     desc: "Maximum number of open Delivery notices per user.",
                     allowed: Integer,
                     default: 20

        add_composer :rate_limit_per_minute,
                     desc: "GET /me/home-notices requests allowed per user per minute.",
                     allowed: Integer,
                     default: 30

        add_composer :mutation_rate_limit_per_minute,
                     desc: "Shared bucket of impression, acknowledge and dismiss requests allowed per user per minute.",
                     allowed: Integer,
                     default: 120

        add_composer :update_app_campaign,
                     desc: "Whether the built-in ct.update_app campaign is active.",
                     allowed: [TrueClass, FalseClass],
                     default: true

        def validate!
          if global_cooldown.nil? || global_cooldown < MINIMUM_GLOBAL_COOLDOWN
            raise ArgumentError, "config.home_notices.global_cooldown must be at least 1 hour"
          end

          self
        end
      end
    end
  end
end
