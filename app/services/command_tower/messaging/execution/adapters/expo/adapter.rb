# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Expo
          # Execution adapter: fans out to eligible push endpoints, sends via Expo
          # Push API, fetches receipts once for ok tickets, and marks invalid devices.
          class Adapter
            DEVICE_INVALID_ERRORS = %w[DeviceNotRegistered].freeze

            EndpointAttempt = Struct.new(
              :endpoint_id,
              :token,
              :ticket,
              :receipt,
              :outcome,
              :error_code,
              keyword_init: true,
            )

            def initialize(configuration: nil, http_client: nil, secret_reader: nil)
              @configuration = configuration || Configuration.new
              @http_client = http_client || HttpClient.new(configuration: @configuration)
              @secret_reader = secret_reader || Endpoints::SecretReader
            end

            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

              rendered = request.rendered
              unless rendered.is_a?(Rendering::RenderedPushPayload)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "render_failed")
              end

              unless @configuration.expo_configured?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              end

              endpoint_ids = Array(request.eligible_endpoint_ids)
              if endpoint_ids.empty?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
              end

              delivery = Messaging::ChannelDelivery.includes(:communication).find_by(id: request.channel_delivery_id)
              owner_user_id = delivery&.communication&.user_id
              if owner_user_id.nil?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
              end

              attempts = build_endpoint_attempts(owner_user_id:, endpoint_ids:)
              return attempts if attempts.is_a?(AdapterResult)

              case @configuration.adapter_name
              when "fake", "log"
                AdapterResult.build(outcome: :success, normalized_provider_status: "accepted")
              when "http"
                deliver_http(attempts:, rendered:, owner_user_id:)
              else
                AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              end
            rescue StandardError
              AdapterResult.build(outcome: :retryable_failure, error_code: "expo_transient")
            end

            private

            def build_endpoint_attempts(owner_user_id:, endpoint_ids:)
              attempts = endpoint_ids.map do |endpoint_id|
                token = @secret_reader.read!(owner_user_id:, endpoint_id:)
                EndpointAttempt.new(endpoint_id:, token:, outcome: nil)
              rescue Endpoints::NotFoundError, Endpoints::ValidationError
                EndpointAttempt.new(
                  endpoint_id:,
                  token: nil,
                  outcome: :terminal_failure,
                  error_code: "recipient_missing",
                )
              end

              if attempts.all? { |attempt| attempt.outcome == :terminal_failure }
                return AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
              end

              attempts
            end

            def deliver_http(attempts:, rendered:, owner_user_id:)
              sendable = attempts.select { |attempt| attempt.token.present? && attempt.outcome.nil? }
              messages = sendable.map { |attempt| expo_message(token: attempt.token, rendered:) }

              send_result = @http_client.send_messages(messages)
              unless send_result[:ok]
                return map_http_failure(send_result[:status_code])
              end

              tickets = Array(send_result[:tickets])
              sendable.each_with_index do |attempt, index|
                ticket = tickets[index]
                attempt.ticket = ticket
                apply_ticket_outcome!(attempt)
              end

              ok_ticket_ids = sendable.filter_map { |attempt| attempt.ticket&.dig(:id) if attempt.ticket&.dig(:status) == "ok" }
              if ok_ticket_ids.any?
                receipts_result = @http_client.get_receipts(ok_ticket_ids)
                if receipts_result[:ok]
                  receipts = receipts_result[:receipts] || {}
                  sendable.each do |attempt|
                    ticket_id = attempt.ticket&.dig(:id)
                    next if ticket_id.nil?
                    next unless attempt.ticket&.dig(:status) == "ok"

                    receipt = receipts[ticket_id]
                    attempt.receipt = receipt
                    apply_receipt_outcome!(attempt)
                  end
                end
                # Missing or failed receipt fetch: ticket ok without receipt stays success (plan).
              end

              sendable.each do |attempt|
                mark_invalid_if_needed!(owner_user_id:, attempt:)
              end

              aggregate_result(attempts)
            end

            def expo_message(token:, rendered:)
              message = {
                "to" => token,
                "title" => rendered.title,
                "body" => rendered.body,
                "sound" => "default",
              }
              if rendered.deep_link.present?
                message["data"] = { "deepLink" => rendered.deep_link }
              end
              message
            end

            def apply_ticket_outcome!(attempt)
              ticket = attempt.ticket
              if ticket.nil?
                attempt.outcome = :retryable_failure
                attempt.error_code = "expo_transient"
                return
              end

              case ticket[:status]
              when "ok"
                attempt.outcome = :success
              when "error"
                if device_invalid_error?(ticket[:error])
                  attempt.outcome = :terminal_failure
                  attempt.error_code = "expo_device_invalid"
                else
                  attempt.outcome = :terminal_failure
                  attempt.error_code = "expo_rejected"
                end
              else
                attempt.outcome = :retryable_failure
                attempt.error_code = "expo_transient"
              end
            end

            def apply_receipt_outcome!(attempt)
              receipt = attempt.receipt
              return if receipt.nil? # pending / missing → keep ticket success

              case receipt[:status]
              when "ok"
                attempt.outcome = :success
              when "error"
                if device_invalid_error?(receipt[:error])
                  attempt.outcome = :terminal_failure
                  attempt.error_code = "expo_device_invalid"
                else
                  attempt.outcome = :terminal_failure
                  attempt.error_code = "expo_rejected"
                end
              end
            end

            def device_invalid_error?(error)
              DEVICE_INVALID_ERRORS.include?(error.to_s)
            end

            def mark_invalid_if_needed!(owner_user_id:, attempt:)
              return unless attempt.error_code == "expo_device_invalid"

              Endpoints.mark_invalid(owner_user_id:, endpoint_id: attempt.endpoint_id)
            rescue StandardError
              nil
            end

            def map_http_failure(status_code)
              if status_code.to_i >= 500 || status_code.to_i == 429
                AdapterResult.build(outcome: :retryable_failure, error_code: "expo_transient")
              else
                AdapterResult.build(outcome: :terminal_failure, error_code: "expo_rejected")
              end
            end

            def aggregate_result(attempts)
              successes = attempts.select { |attempt| attempt.outcome == :success }
              if successes.any?
                first_ticket_id = successes.filter_map { |attempt| attempt.ticket&.dig(:id) }.first
                return AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: "accepted",
                  provider_message_id: first_ticket_id,
                )
              end

              if attempts.all? { |attempt| attempt.outcome == :terminal_failure }
                error_code = attempts.map(&:error_code).compact.first || "expo_rejected"
                return AdapterResult.build(outcome: :terminal_failure, error_code:)
              end

              AdapterResult.build(outcome: :retryable_failure, error_code: "expo_transient")
            end
          end
        end
      end
    end
  end
end
