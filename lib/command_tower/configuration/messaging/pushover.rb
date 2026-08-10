# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Pushover < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        ADAPTERS = %w[disabled fake log http].freeze

        add_composer :adapter,
          desc: "Pushover verification transport: disabled | fake | log | http. Default disabled (fail closed).",
          allowed: String,
          default: "disabled",
          validator: ->(val) { ADAPTERS.include?(val.to_s) },
          invalid_message: ->(val) { "Provided #{val.inspect}. Allowed: #{ADAPTERS.join(', ')}" }

        add_composer :api_base_url,
          desc: "Pushover API base URL (versioned path included).",
          allowed: String,
          default: "https://api.pushover.net/1"

        add_composer :timeout_seconds,
          desc: "HTTP open/read timeout seconds for Pushover provider calls.",
          allowed: Integer,
          default: 5

        add_composer :test_title,
          desc: "Title for Pushover verification/test notification. Neutral default; hosts override product copy.",
          allowed: String,
          default: "Pushover verification"

        add_composer :test_message,
          desc: "Body for Pushover verification/test notification.",
          allowed: String,
          default: "Your Pushover credentials were verified successfully."
      end
    end
  end
end
