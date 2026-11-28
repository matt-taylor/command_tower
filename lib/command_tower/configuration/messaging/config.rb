# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/messaging/sms"
require "command_tower/configuration/messaging/pushover"
require "command_tower/configuration/messaging/expo"
require "command_tower/configuration/messaging/compliance"
require "command_tower/configuration/messaging/inbox"

module CommandTower
  module Configuration
    module Messaging
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :allow_fake_adapter,
          desc: "Platform testing/development execution override: when true, Execution selects " \
                "Execution::Adapters::FakeAdapter for any channel. Not provider configuration — " \
                "intentionally separate from config.messaging.sms.adapter / pushover.adapter. " \
                "Default false (fail-closed). Precedence: injected executor → this flag → " \
                "normal provider adapter selection.",
          allowed: [TrueClass, FalseClass],
          default: false

        add_composer :platform_enabled_channels,
          desc: "Host-owned callable returning the Array of channel keys currently enabled for " \
                "this platform (Preferences HTTP, Accept/Planner injection). CommandTower does " \
                "not invent product enablement; hosts assign a Proc (e.g. wrapping " \
                "PlatformEnabledChannels). Default fail-closed empty list.",
          allowed: [Proc],
          default: -> { [] },
          default_shown: "-> { [] }"

        add_composer :welcome_content,
          desc: "Host-owned callable returning nil or a Hash of welcome Produce fields " \
                "({ notification_type_key:, title:, body:, metadata? }). " \
                "Default nil Proc → RegisterWorkflow skips welcome emit. " \
                "CommandTower does not own product welcome copy.",
          allowed: [Proc],
          default: -> { nil },
          default_shown: "-> { nil }"

        add_composer :resolve_announcement_audience,
          desc: "Host-owned callable receiving a selection Hash ({ mode:, ids? }) and returning " \
                "an Array of Integer user ids for ProduceMany. Default empty list (fail-closed). " \
                "CommandTower never runs product audience queries.",
          allowed: [Proc],
          default: ->(_selection) { [] },
          default_shown: "->(_selection) { [] }"

        add_composer :sounds,
          desc: "Host-registered push sounds appended to the engine's System Default " \
                "(id \"default\", no bundled asset). Array of { id:, label:, asset: } hashes; " \
                "`asset` is the native file reference. Ids are lowercase snake_case and unique. " \
                "Physical asset availability is verified by the iOS app, not here. " \
                "Validated at notification-type registry seal.",
          allowed: Array,
          default: [],
          default_shown: "[]"

        add_composer :sms,
          desc: "Messaging notification SMS delivery configuration (not Identity OTP)",
          allowed: Sms,
          default: Sms.new

        add_composer :pushover,
          desc: "Pushover verification transport configuration (credential validate + test notification)",
          allowed: Pushover,
          default: Pushover.new

        add_composer :expo,
          desc: "Expo Push delivery configuration (Messaging push channel; optional access_token)",
          allowed: Expo,
          default: Expo.new

        add_composer :compliance,
          desc: "Email compliance configuration for MessageDefinition types (unsubscribe origin, " \
                "preferences path, postal address, token secret)",
          allowed: Compliance,
          default: Compliance.new

        add_composer :inbox,
          desc: "Inbox behaviour configuration (thread restore on a new message)",
          allowed: Inbox,
          default: Inbox.new

        add_composer :strict_definitions,
          desc: "When true, MessageDefinition violations (metadata schema, explicit copy on a defined " \
                "type) fail the request; when false they are logged and degraded. Default true in " \
                "development and test, false in production.",
          allowed: [TrueClass, FalseClass, NilClass],
          default: nil,
          default_shown: "!Rails.env.production?"

        # nil means "not set by the host": resolve from the Rails env at call time.
        alias configured_strict_definitions strict_definitions

        def strict_definitions
          configured = configured_strict_definitions
          return configured unless configured.nil?

          !(defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.production?)
        end
      end
    end
  end
end
