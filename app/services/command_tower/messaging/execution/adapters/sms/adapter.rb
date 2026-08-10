# frozen_string_literal: true

require "net/http"
require "socket"
require "timeout"

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Sms
          class Adapter
            E164 = /\A\+[1-9]\d{1,14}\z/

            RETRYABLE_HTTP_STATUSES = [408, 429, 500, 502, 503, 504].freeze
            AUTH_HTTP_STATUSES = [401, 403].freeze

            def initialize(http_client: nil, configuration: nil)
              @http_client = http_client
              @configuration = configuration || Configuration.new
            end

            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)
              rendered = request.rendered
              unless rendered.is_a?(Rendering::RenderedSmsPayload)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "render_failed")
              end

              unless @configuration.sms_configured?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              end

              to = rendered.recipient_address.to_s
              unless to.match?(E164)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "invalid_recipient")
              end

              begin
                response = client.create_message(
                  to:,
                  body: rendered.body,
                  from: @configuration.use_messaging_service? ? nil : @configuration.from_number,
                  messaging_service_sid: @configuration.use_messaging_service? ? @configuration.messaging_service_sid : nil,
                )
                map_response(response)
              rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
                AdapterResult.build(outcome: :retryable_failure, error_code: "twilio_transient")
              rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError
                AdapterResult.build(outcome: :retryable_failure, error_code: "twilio_transient")
              rescue StandardError
                AdapterResult.build(outcome: :retryable_failure, error_code: "twilio_transient")
              end
            end

            private

            def client
              @http_client || TwilioHttpClient.new(
                account_sid: @configuration.account_sid,
                auth_token: @configuration.auth_token,
              )
            end

            def map_response(response)
              if response[:ok]
                return AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: response[:provider_status] || "queued",
                  provider_message_id: response[:sid],
                )
              end

              status = response[:status_code].to_i
              if AUTH_HTTP_STATUSES.include?(status)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "twilio_auth_failed")
              end

              if RETRYABLE_HTTP_STATUSES.include?(status)
                return AdapterResult.build(outcome: :retryable_failure, error_code: "twilio_transient")
              end

              AdapterResult.build(outcome: :terminal_failure, error_code: "twilio_rejected")
            end
          end
        end
      end
    end
  end
end
