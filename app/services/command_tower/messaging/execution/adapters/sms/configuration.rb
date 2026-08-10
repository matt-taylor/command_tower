# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Sms
          # Platform readiness detector for notification SMS.
          # Ready only when adapter is twilio and credentials + sender are complete.
          # disabled / fake / log never count as platform_configured.
          class Configuration
            def self.sms_configured?
              new.sms_configured?
            end

            def sms_configured?
              return false unless adapter_name == "twilio"

              account_sid.present? && auth_token.present? && sender_identity_present?
            end

            def adapter_name
              CommandTower.config.messaging.sms.adapter.to_s
            end

            def account_sid
              CredentialResolution.resolve(:twilio).account_sid
            end

            def auth_token
              CredentialResolution.resolve(:twilio).auth_token
            end

            # Prefer Messaging Service SID when both sender mechanisms are set.
            def messaging_service_sid
              CommandTower.config.messaging.sms.messaging_service_sid.to_s.strip.presence
            end

            def from_number
              configured = CommandTower.config.messaging.sms.from_number.to_s.strip.presence
              configured ||
                ENV["TWILIO_FROM"].to_s.strip.presence ||
                ENV["TWILIO_FROM_NUMBER"].to_s.strip.presence
            end

            def sender_identity_present?
              messaging_service_sid.present? || from_number.present?
            end

            def use_messaging_service?
              messaging_service_sid.present?
            end
          end
        end
      end
    end
  end
end
