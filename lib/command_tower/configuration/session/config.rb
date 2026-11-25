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
        OMIT_BODY_TOKEN_ENV = "COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN"
        OMIT_BODY_TOKEN_MIN_VERSION_ENV = "COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN_MIN_APP_VERSION"

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

        add_composer :omit_body_token,
                     desc: "In cookie mode, omit `token` from the login response body for the new web client " \
                           "only (X-Client-Platform: web, X-App-Version at or above " \
                           "omit_body_token_min_app_version). Read from ENV",
                     allowed: [TrueClass, FalseClass],
                     default: ENV.fetch(OMIT_BODY_TOKEN_ENV, "true") != "false",
                     default_shown: "ENV.fetch(\"#{OMIT_BODY_TOKEN_ENV}\", \"true\") != \"false\""

        add_composer :omit_body_token_min_app_version,
                     desc: "First web X-App-Version (MAJOR.MINOR.PATCH) that no longer reads the body token. " \
                           "Read from ENV",
                     allowed: String,
                     default: ENV.fetch(OMIT_BODY_TOKEN_MIN_VERSION_ENV, "0.4.0"),
                     default_shown: "ENV.fetch(\"#{OMIT_BODY_TOKEN_MIN_VERSION_ENV}\", \"0.4.0\")"
      end
    end
  end
end
