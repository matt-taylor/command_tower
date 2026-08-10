# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Sms
          # Narrowly scoped Twilio Messages HTTP client for Messaging notification SMS.
          # Not shared with Identity OTP transport.
          class TwilioHttpClient
            API_BASE = "https://api.twilio.com/2010-04-01"

            def initialize(account_sid:, auth_token:)
              @account_sid = account_sid
              @auth_token = auth_token
            end

            # Returns a hash: { ok:, status_code:, body:, sid:, provider_status:, error_code: }
            def create_message(to:, body:, from: nil, messaging_service_sid: nil)
              uri = URI("#{API_BASE}/Accounts/#{@account_sid}/Messages.json")
              request = Net::HTTP::Post.new(uri)
              request.basic_auth(@account_sid, @auth_token)

              form = { "To" => to, "Body" => body }
              if messaging_service_sid.present?
                form["MessagingServiceSid"] = messaging_service_sid
              else
                form["From"] = from
              end
              request.set_form_data(form)

              response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
                http.request(request)
              end

              parse_response(response)
            end

            private

            def parse_response(response)
              parsed = parse_json(response.body)
              sid = parsed.is_a?(Hash) ? (parsed["sid"] || parsed[:sid]).to_s.presence : nil
              provider_status = parsed.is_a?(Hash) ? (parsed["status"] || parsed[:status]).to_s.presence : nil
              provider_error = parsed.is_a?(Hash) ? (parsed["code"] || parsed[:code] || parsed["error_code"]).to_s.presence : nil

              {
                ok: response.is_a?(Net::HTTPSuccess),
                status_code: response.code.to_i,
                sid:,
                provider_status:,
                provider_error_code: provider_error,
              }
            end

            def parse_json(body)
              JSON.parse(body.to_s)
            rescue JSON::ParserError
              nil
            end
          end
        end
      end
    end
  end
end
