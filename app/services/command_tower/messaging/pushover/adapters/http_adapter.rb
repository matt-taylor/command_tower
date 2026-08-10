# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module CommandTower
  module Messaging
    module Pushover
      module Adapters
        # Real Pushover HTTP client for credential validation, test notifications,
        # and production delivery. Never returns or logs secrets / raw provider payloads.
        class HttpAdapter
          def validate_user!(user_key:, application_token:)
            post_form(
              path: "users/validate.json",
              form: {
                "token" => application_token.to_s,
                "user" => user_key.to_s,
              },
            )
          end

          def send_test_notification!(user_key:, application_token:, title:, message:)
            post_form(
              path: "messages.json",
              form: {
                "token" => application_token.to_s,
                "user" => user_key.to_s,
                "title" => title.to_s,
                "message" => message.to_s,
              },
            )
          end

          def send_message!(user_key:, application_token:, title:, message:)
            post_form(
              path: "messages.json",
              form: {
                "token" => application_token.to_s,
                "user" => user_key.to_s,
                "title" => title.to_s,
                "message" => message.to_s,
              },
            )
          end

          private

          def post_form(path:, form:)
            config = CommandTower.config.messaging.pushover
            uri = URI.join("#{config.api_base_url.to_s.chomp('/')}/", path)
            timeout = config.timeout_seconds.to_i
            timeout = 5 if timeout <= 0

            request = Net::HTTP::Post.new(uri)
            request.set_form_data(form)

            response = Net::HTTP.start(
              uri.hostname,
              uri.port,
              use_ssl: uri.scheme == "https",
              open_timeout: timeout,
              read_timeout: timeout,
            ) do |http|
              http.request(request)
            end

            classify_response(response)
          rescue Net::OpenTimeout, Net::ReadTimeout
            Result.failure(error_code: :timeout, error_message: "Pushover provider timed out")
          rescue StandardError
            Result.failure(error_code: :provider_unavailable, error_message: "Pushover provider unavailable")
          end

          def classify_response(response)
            status = response.code.to_i
            body = parse_json(response.body)
            status_ok = body.is_a?(Hash) && body["status"].to_i == 1
            request_id = body.is_a?(Hash) ? body["request"].to_s.presence : nil

            if response.is_a?(Net::HTTPSuccess) && status_ok
              return Result.ok(provider_request_id: request_id)
            end

            errors = Array(body.is_a?(Hash) ? body["errors"] : nil).map(&:to_s)
            joined = errors.join(" ").downcase

            if status == 429
              return Result.failure(
                error_code: :rate_limited,
                error_message: "Pushover provider rate limited the request",
                provider_request_id: request_id,
              )
            end

            if joined.include?("application token") || joined.include?("app token") || joined.include?("invalid token")
              return Result.failure(
                error_code: :invalid_token,
                error_message: "Pushover application token is invalid",
                provider_request_id: request_id,
              )
            end

            if joined.include?("user key") || joined.include?("user is invalid") || joined.include?("user key is invalid")
              return Result.failure(
                error_code: :invalid_user,
                error_message: "Pushover user key is invalid",
                provider_request_id: request_id,
              )
            end

            if status == 400
              return Result.failure(
                error_code: :invalid_credentials,
                error_message: "Pushover credentials were rejected",
                provider_request_id: request_id,
              )
            end

            if status >= 500
              return Result.failure(
                error_code: :provider_unavailable,
                error_message: "Pushover provider unavailable",
                provider_request_id: request_id,
              )
            end

            Result.failure(
              error_code: :provider_unavailable,
              error_message: "Pushover provider rejected the request",
              provider_request_id: request_id,
            )
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
