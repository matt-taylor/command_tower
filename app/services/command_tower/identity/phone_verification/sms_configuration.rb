# frozen_string_literal: true

module CommandTower
  module Identity
    module PhoneVerification
      # Readiness detector for Identity phone-verification OTP SMS delivery.
      # Distinct from Messaging notification SMS Configuration — same Twilio ENV
      # names may be shared, but adapters and sender resolution differ.
      class SmsConfiguration
        def self.sms_ready?
          new.sms_ready?
        end

        def sms_ready?
          return false unless phone_verification.enable

          case adapter_name
          when "twilio"
            twilio_credentials_present?
          when "fake", "log"
            # Intentional non-provider transports for test/development only.
            !Rails.env.production?
          else
            false
          end
        end

        def adapter_name
          phone_verification.sms_adapter.to_s
        end

        private

        def phone_verification
          CommandTower.config.identity.phone_verification
        end

        def twilio_credentials_present?
          account_sid.present? && auth_token.present? && from_number.present?
        end

        def account_sid
          CredentialResolution.resolve(:twilio).account_sid
        end

        def auth_token
          CredentialResolution.resolve(:twilio).auth_token
        end

        def from_number
          phone_verification.sms_from.to_s.strip.presence ||
            ENV["TWILIO_FROM"].to_s.strip.presence ||
            ENV["TWILIO_FROM_NUMBER"].to_s.strip.presence
        end
      end
    end
  end
end
