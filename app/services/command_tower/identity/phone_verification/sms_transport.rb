# frozen_string_literal: true

module CommandTower
  module Identity
    module PhoneVerification
      # Vendor-agnostic SMS delivery for phone OTP. Identity depends on this interface only.
      module SmsTransport
        Result = Struct.new(:success?, :error_code, :error_message, keyword_init: true)

        class << self
          attr_writer :adapter

          def adapter
            @adapter ||= build_adapter
          end

          def reset_adapter!
            @adapter = nil
          end

          def deliver(to:, body:)
            adapter.deliver(to: to, body: body)
          end

          private

          def build_adapter
            name = CommandTower.config.identity.phone_verification.sms_adapter.to_s
            case name
            when "twilio"
              Adapters::TwilioAdapter.new
            when "log"
              Adapters::LogAdapter.new
            else
              Adapters::FakeAdapter.new
            end
          end
        end
      end
    end
  end
end
