# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Expo < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        ADAPTERS = %w[disabled fake log http].freeze

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
      end
    end
  end
end
