# frozen_string_literal: true

module CommandTower
  module Messaging
    # Shared platform channel configuration detectors.
    #
    # Answers transport/deployment readiness questions (is email/SMS/Pushover
    # configured?). Does not own host channel-set policy (PlatformEnabledChannels),
    # recipient readiness, or Account UX capability projection.
    #
    # SMS product readiness (Messaging notification SMS ∧ Identity OTP SMS) is
    # exposed separately from sms_configured? so Planner/Execution platform_configured
    # stays Messaging-only while Me phone HTTP / host SMS policy use the dual-gate.
    module ChannelDetectors
      module_function

      def email_configured?
        Execution::Adapters::Email::Configuration.email_configured?
      end

      def sms_configured?
        Execution::Adapters::Sms::Configuration.sms_configured?
      end

      def pushover_configured?
        Execution::Adapters::Pushover::Configuration.pushover_configured?
      end

      # Used by RecipientReadiness#platform_configured_for? (fail-closed).
      def configured?(channel_key)
        case channel_key.to_s
        when "inbox"
          true
        when "email"
          email_configured?
        when "sms"
          sms_configured?
        when "pushover"
          pushover_configured?
        else
          false
        end
      end

      # Messaging notification SMS ∧ Identity OTP SMS.
      def sms_product_ready?
        sms_configured? &&
          CommandTower::Identity::PhoneVerification::SmsConfiguration.sms_ready?
      end
    end
  end
end
