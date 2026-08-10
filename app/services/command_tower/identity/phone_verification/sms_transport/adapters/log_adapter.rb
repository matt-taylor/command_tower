# frozen_string_literal: true

module CommandTower
  module Identity
    module PhoneVerification
      module SmsTransport
        module Adapters
          # Logs masked destination only — never OTP body in production logs.
          class LogAdapter
            def deliver(to:, body:)
              Rails.logger.info(
                {
                  event: "phone_verification_sms_log_adapter",
                  to_masked: mask_phone(to),
                  body_length: body.to_s.length
                }.to_json
              )
              SmsTransport::Result.new(success?: true, error_code: nil, error_message: nil)
            end

            private

            def mask_phone(value)
              digits = value.to_s.gsub(/\D/, "")
              return "[redacted]" if digits.length < 4

              "#{"*" * (digits.length - 4)}#{digits[-4,]}"
            end
          end
        end
      end
    end
  end
end
