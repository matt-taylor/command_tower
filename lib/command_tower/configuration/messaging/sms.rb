# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Sms < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        ADAPTERS = %w[disabled fake twilio log].freeze

        add_composer :adapter,
          desc: "Messaging notification SMS adapter: disabled | fake | twilio | log. Default disabled (fail closed).",
          allowed: String,
          default: "disabled",
          validator: ->(val) { ADAPTERS.include?(val.to_s) },
          invalid_message: ->(val) { "Provided #{val.inspect}. Allowed: #{ADAPTERS.join(', ')}" }

        add_composer :from_number,
          desc: "Sender phone number for Twilio notification SMS (E.164). Falls back to ENV TWILIO_FROM when blank.",
          allowed: [String, NilClass],
          default: nil

        add_composer :messaging_service_sid,
          desc: "Twilio Messaging Service SID for notification SMS. Preferred over from_number when both are set.",
          allowed: [String, NilClass],
          default: nil
      end
    end
  end
end
