# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/messaging/sms"
require "command_tower/configuration/messaging/pushover"

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

        add_composer :sms,
          desc: "Messaging notification SMS delivery configuration (not Identity OTP)",
          allowed: Sms,
          default: Sms.new

        add_composer :pushover,
          desc: "Pushover verification transport configuration (credential validate + test notification)",
          allowed: Pushover,
          default: Pushover.new
      end
    end
  end
end
