# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Identity
      class PhoneVerification < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        # Same validation style as Configuration::Messaging::Sms (ADAPTERS + ClassComposer validator).
        ADAPTERS = %w[fake log twilio].freeze

        add_composer :enable,
          desc: "Enable Identity phone verification OTP send/verify",
          allowed: [FalseClass, TrueClass],
          default: true

        add_composer :verify_code_length,
          desc: "Length of the numeric phone verification OTP (Generate + Identity Policy)",
          allowed: Integer,
          default: 6,
          validator: ->(val) { (val <= 10) && (val >= 4) },
          invalid_message: ->(val) { "Provided #{val}. Value must be between 4 and 10 inclusive." }

        add_composer :verify_code_valid_for,
          desc: "How long a phone verification OTP remains valid",
          allowed: ActiveSupport::Duration,
          default: 10.minutes,
          validator: ->(val) { val < 60.minutes },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than #{60.minutes}" }

        add_composer :resend_cooldown,
          desc: "Minimum time between phone verification OTP sends for the same user",
          allowed: ActiveSupport::Duration,
          default: 30.seconds,
          validator: ->(val) { val >= 0.seconds && val < 60.minutes },
          invalid_message: ->(val) { "Provided #{val}. Value must be >= 0 and less than #{60.minutes}" }

        add_composer :sms_from,
          desc: "Sender identity for phone verification SMS (provider-specific)",
          allowed: [String, NilClass],
          default: nil

        add_composer :sms_adapter,
          desc: "SMS transport adapter name: fake | log | twilio",
          allowed: String,
          default: "fake",
          validator: ->(val) { ADAPTERS.include?(val.to_s) },
          invalid_message: ->(val) { "Provided #{val.inspect}. Allowed: #{ADAPTERS.join(', ')}" }
      end
    end
  end
end
