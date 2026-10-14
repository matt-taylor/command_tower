# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Expo < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        ADAPTERS = %w[disabled fake log http].freeze
        # Mirrors Messaging::NotificationTypes::URGENCY_LEVELS. Kept literal because this file
        # loads before the app's autoloaded constants; a spec keeps the two in step.
        INTERRUPTION_LEVELS = %w[normal time_sensitive critical].freeze

        add_composer :adapter,
          desc: "Expo Push delivery: disabled | fake | log | http. Default disabled (fail closed).",
          allowed: String,
          default: "disabled",
          validator: ->(val) { ADAPTERS.include?(val.to_s) },
          invalid_message: ->(val) { "Provided #{val.inspect}. Allowed: #{ADAPTERS.join(', ')}" }

        add_composer :api_base_url,
          desc: "Expo Push API origin (send = {base}/send, receipts = {base}/getReceipts).",
          allowed: String,
          default: "https://exp.host/--/api/v2/push"

        add_composer :timeout_seconds,
          desc: "HTTP open/read timeout seconds for Expo Push provider calls.",
          allowed: Integer,
          default: 5

        add_composer :access_token,
          desc: "Optional Expo Push access token. When non-blank, send Authorization: Bearer. " \
                "Required only if the Expo project enables enhanced push security. Never log.",
          allowed: String,
          default: ""

        add_composer :self_test_per_user_hour,
          desc: "Max Me push self-test (POST /me/push/test) sends allowed per user per rolling window. " \
                "Hosts enabling Account Push notifications settings should set this explicitly " \
                "(Pick'em: 10).",
          allowed: Integer,
          default: 10

        add_composer :self_test_window_seconds,
          desc: "Rolling window length in seconds for Me push self-test rate limiting " \
                "(default 3600 = one hour).",
          allowed: Integer,
          default: 3600

        add_composer :home_deep_link,
          desc: "Host Home deep link used when a push has no metadata deep_link and no live inbox item. " \
                "String or zero-argument Proc. Seal checks presence and does not call a Proc. " \
                "Required when a push-capable type is registered and the Expo adapter is not disabled.",
          allowed: [String, Proc, NilClass],
          default: nil

        add_composer :self_test_deep_link,
          desc: "Deep link for the account push self-test. String or zero-argument Proc. " \
                "Resolved only when SendSelfTest runs. Blank fails the test before Produce.",
          allowed: [String, Proc, NilClass],
          default: nil

        add_composer :interruption_levels,
          desc: "Urgency levels this host's shipped iOS binary can honor, as Expo `interruptionLevel`. " \
                "Subset of normal, time_sensitive, critical. `normal` is always supported. A declared " \
                "urgency above this set degrades critical -> time_sensitive -> normal. Add `time_sensitive` " \
                "only after the binary carries the Time Sensitive capability, and `critical` only with " \
                "Apple's Critical Alerts entitlement. Default normal only.",
          allowed: Array,
          default: ["normal"],
          default_shown: '["normal"]',
          validator: ->(val) { val.all? { |level| INTERRUPTION_LEVELS.include?(level) } },
          invalid_message: ->(val) { "Provided #{val.inspect}. Allowed levels: #{INTERRUPTION_LEVELS.join(', ')}" }

        def home_deep_link_configured?
          link_configured?(home_deep_link)
        end

        def resolve_home_deep_link
          resolve_link(home_deep_link)
        end

        def self_test_deep_link_configured?
          link_configured?(self_test_deep_link)
        end

        def resolve_self_test_deep_link
          resolve_link(self_test_deep_link)
        end

        private

        def link_configured?(value)
          return true if value.respond_to?(:call)
          return false unless value.is_a?(String)

          !value.strip.empty?
        end

        def resolve_link(value)
          resolved = value.respond_to?(:call) ? value.call : value
          return nil unless resolved.is_a?(String)

          stripped = resolved.strip
          stripped.empty? ? nil : stripped
        end
      end
    end
  end
end
