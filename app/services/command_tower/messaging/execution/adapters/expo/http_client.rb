# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Expo
          # Narrow Expo Push HTTP client for Messaging notification push.
          # Never logs tokens, Authorization headers, or raw bodies that may contain tokens.
          class HttpClient
            def initialize(configuration: nil)
              @configuration = configuration || Configuration.new
            end

            # messages: Array of Expo message hashes (to/title/body/data).
            # Returns { ok:, status_code:, tickets: [...] } where each ticket is
            # { status:, id:, message:, error: } (error is Expo details.error when present).
            def send_messages(messages)
              # Expo Push /send accepts a JSON array of messages.
              response = post_json("#{api_base_url}/send", Array(messages))
              parse_send_response(response)
            end

            # ids: Array of ticket id strings.
            # Returns { ok:, status_code:, receipts: { id => { status:, message:, error: } } }
            def get_receipts(ids)
              response = post_json("#{api_base_url}/getReceipts", { "ids" => Array(ids) })
              parse_receipts_response(response)
            end

            private

            def api_base_url
              @configuration.api_base_url.to_s.sub(%r{/\z}, "")
            end

            def timeout_seconds
              seconds = @configuration.timeout_seconds.to_i
              seconds.positive? ? seconds : 5
            end

            def access_token
              @configuration.access_token.to_s.strip
            end

            def post_json(url, payload)
              uri = URI(url)
              request = Net::HTTP::Post.new(uri)
              request["Content-Type"] = "application/json"
              request["Accept"] = "application/json"
              token = access_token
              request["Authorization"] = "Bearer #{token}" unless token.empty?
              request.body = JSON.generate(payload)

              Net::HTTP.start(
                uri.hostname,
                uri.port,
                use_ssl: uri.scheme == "https",
                open_timeout: timeout_seconds,
                read_timeout: timeout_seconds,
              ) do |http|
                http.request(request)
              end
            end

            def parse_send_response(response)
              parsed = parse_json(response.body)
              data = parsed.is_a?(Hash) ? parsed["data"] : nil
              tickets =
                if data.is_a?(Array)
                  data.map { |ticket| normalize_ticket(ticket) }
                else
                  []
                end

              {
                ok: response.is_a?(Net::HTTPSuccess),
                status_code: response.code.to_i,
                tickets:,
              }
            end

            def parse_receipts_response(response)
              parsed = parse_json(response.body)
              data = parsed.is_a?(Hash) ? parsed["data"] : nil
              receipts = {}
              if data.is_a?(Hash)
                data.each do |ticket_id, receipt|
                  receipts[ticket_id.to_s] = normalize_receipt(receipt)
                end
              end

              {
                ok: response.is_a?(Net::HTTPSuccess),
                status_code: response.code.to_i,
                receipts:,
              }
            end

            def normalize_ticket(ticket)
              hash = ticket.is_a?(Hash) ? ticket : {}
              details = hash["details"] || hash[:details]
              error = details.is_a?(Hash) ? (details["error"] || details[:error]) : nil
              {
                status: (hash["status"] || hash[:status]).to_s,
                id: (hash["id"] || hash[:id])&.to_s,
                message: (hash["message"] || hash[:message])&.to_s,
                error: error&.to_s,
              }
            end

            def normalize_receipt(receipt)
              hash = receipt.is_a?(Hash) ? receipt : {}
              details = hash["details"] || hash[:details]
              error = details.is_a?(Hash) ? (details["error"] || details[:error]) : nil
              {
                status: (hash["status"] || hash[:status]).to_s,
                message: (hash["message"] || hash[:message])&.to_s,
                error: error&.to_s,
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
