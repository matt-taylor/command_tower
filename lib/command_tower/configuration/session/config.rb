# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Session
      # Device session (signed-in device) timeouts and switches.
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        ENFORCE_ENV = "COMMAND_TOWER_SESSION_ENFORCE"
        UPGRADE_LEGACY_ENV = "COMMAND_TOWER_SESSION_UPGRADE_LEGACY_TOKENS"

        add_composer :idle_timeout,
                     desc: "A device session with no authenticated request for this long is expired",
                     allowed: ActiveSupport::Duration,
                     default: 30.days

        add_composer :absolute_timeout,
                     desc: "Maximum lifetime of a device session from creation, regardless of activity",
                     allowed: ActiveSupport::Duration,
                     default: 90.days

        add_composer :last_seen_write_interval,
                     desc: "last_seen_at is written at most once per this interval per session",
                     allowed: ActiveSupport::Duration,
                     default: 5.minutes

        add_composer :enforce,
                     desc: "Kill switch. When false the revoked and idle checks are skipped. Read from ENV",
                     allowed: [TrueClass, FalseClass],
                     default: ENV.fetch(ENFORCE_ENV, "true") != "false",
                     default_shown: "ENV.fetch(\"#{ENFORCE_ENV}\", \"true\") != \"false\""

        add_composer :upgrade_legacy_tokens,
                     desc: "Upgrade sid-less legacy tokens to a device session on GET /auth/session",
                     allowed: [TrueClass, FalseClass],
                     default: ENV.fetch(UPGRADE_LEGACY_ENV, "true") != "false",
                     default_shown: "ENV.fetch(\"#{UPGRADE_LEGACY_ENV}\", \"true\") != \"false\""
      end
    end
  end
end
