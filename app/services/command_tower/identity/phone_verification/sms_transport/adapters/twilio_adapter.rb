# frozen_string_literal: true

require "net/http"
require "uri"

module CommandTower
  module Identity
    module PhoneVerification
      module SmsTransport
        module Adapters
          # Smallest Twilio REST adapter. Requires Twilio credentials via
          # CredentialResolution and identity.phone_verification.sms_from (or TWILIO_FROM).
          class TwilioAdapter
            def deliver(to:, body:)
              twilio = CredentialResolution.resolve(:twilio)
              account_sid = twilio.account_sid
              auth_token = twilio.auth_token
              from = CommandTower.config.identity.phone_verification.sms_from.presence ||
                ENV["TWILIO_FROM"].to_s.presence ||
                ENV["TWILIO_FROM_NUMBER"].to_s.presence

              if account_sid.blank? || auth_token.blank? || from.blank?
                return SmsTransport::Result.new(
                  success?: false,
                  error_code: :configuration_unavailable,
                  error_message: "SMS provider is not configured"
                )
              end

              uri = URI("https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json")
              request = Net::HTTP::Post.new(uri)
              request.basic_auth(account_sid, auth_token)
              request.set_form_data("To" => to, "From" => from, "Body" => body)

              response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
                http.request(request)
              end

              if response.is_a?(Net::HTTPSuccess)
                SmsTransport::Result.new(success?: true, error_code: nil, error_message: nil)
              else
                SmsTransport::Result.new(
                  success?: false,
                  error_code: :provider_unavailable,
                  error_message: "SMS provider rejected the request"
                )
              end
            rescue StandardError
              SmsTransport::Result.new(
                success?: false,
                error_code: :provider_unavailable,
                error_message: "SMS provider unavailable"
              )
            end
          end
        end
      end
    end
  end
end
