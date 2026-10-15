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
              :submitted,
              keyword_init: true,
            )

            def initialize(configuration: nil, http_client: nil, secret_reader: nil)
              @configuration = configuration || Configuration.new
              @http_client = http_client || HttpClient.new(configuration: @configuration)
              @secret_reader = secret_reader || Endpoints::SecretReader
            end

            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

              attempts = nil
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

              delivery = Messaging::ChannelDelivery.includes(communication: :inbox_item).find_by(id: request.channel_delivery_id)
              owner_user_id = delivery&.communication&.user_id
              if owner_user_id.nil?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
              end

              history = EndpointTicketHistory.call(
                channel_delivery_id: delivery.id,
                excluding_attempt_id: request.attempt_id,
              )
              unsettled_ids = endpoint_ids - history.settled_endpoint_ids
              return settled_only_result(history) if unsettled_ids.empty?

              attempts = build_endpoint_attempts(owner_user_id:, endpoint_ids: unsettled_ids)
              return attempts if attempts.is_a?(AdapterResult)

              case @configuration.adapter_name
              when "fake", "log"
                AdapterResult.build(outcome: :success, normalized_provider_status: "accepted")
              when "http"
                deliver_http(
                  attempts:,
                  rendered:,
                  owner_user_id:,
                  history:,
                  communication: delivery.communication,
                )
              else
                AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              end
            rescue HttpClient::RequestNotSubmitted
              not_submitted_result(attempts, history:)
            rescue StandardError
              uncertain_terminal_result(attempts, history:)
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

            def deliver_http(attempts:, rendered:, owner_user_id:, history:, communication:)
              sendable = attempts.select { |attempt| attempt.token.present? && attempt.outcome.nil? }
              messages = sendable.map { |attempt| expo_message(token: attempt.token, rendered:, communication:) }

              send_result = @http_client.send_messages(messages)
              sendable.each { |attempt| attempt.submitted = true }
              unless send_result[:ok]
                return map_http_failure(send_result[:status_code], attempts:, history:)
              end

              tickets = Array(send_result[:tickets])
              sendable.each_with_index do |attempt, index|
                ticket = tickets[index]
                attempt.ticket = ticket
                apply_ticket_outcome!(attempt)
              end

              ok_ticket_ids = sendable.filter_map { |attempt| attempt.ticket&.dig(:id) if attempt.ticket&.dig(:status) == "ok" }
              if ok_ticket_ids.any?
                receipts_result = fetch_receipts(ok_ticket_ids)
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

              aggregate_result(attempts, history:)
            end

            def fetch_receipts(ticket_ids)
              @http_client.get_receipts(ticket_ids)
            rescue StandardError
              { ok: false, status_code: nil, receipts: {} }
            end

            # Every eligible endpoint already holds an accepted ticket or a recorded terminal
            # ticket error from an earlier attempt, so there is nothing to send.
            def settled_only_result(history)
              if history.accepted?
                return AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: "accepted",
                  provider_message_id: history.first_accepted_ticket_id,
                )
              end

              AdapterResult.build(
                outcome: :terminal_failure,
                error_code: history.first_terminal_error_code || "expo_rejected",
              )
            end

            def expo_message(token:, rendered:, communication:)
              message = {
                "to" => token,
                "title" => rendered.title,
                "body" => rendered.body,
                "sound" => rendered.sound || "default",
              }
              interruption_level = InterruptionLevel.call(
                urgency: rendered.urgency,
                supported: @configuration.supported_interruption_levels,
              )
              message["interruptionLevel"] = interruption_level if interruption_level
              message["threadId"] = rendered.thread_id if rendered.thread_id
              # nil omits the field. 0 is a real count and must be sent. In Ruby, 0 is truthy.
              message["badge"] = rendered.badge unless rendered.badge.nil?
              data = {}
              data["deepLink"] = rendered.deep_link if rendered.deep_link.present?
              item = communication&.inbox_item
              if item&.live_for_push?
                data["inboxItemId"] = item.id.to_s
                data["inboxEntryId"] = communication.conversation_key.presence || item.id.to_s
              end
              message["data"] = data if data.any?
              message
            end

            def apply_ticket_outcome!(attempt)
              ticket = attempt.ticket
              if ticket.nil?
                attempt.outcome = :terminal_failure
                attempt.error_code = submission_uncertain_code
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
                attempt.outcome = :terminal_failure
                attempt.error_code = submission_uncertain_code
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

            # After the HTTP client returns, a non-success response is uncertain for duplicate policy
            # (request may have been accepted). Terminal rejection (4xx except 429) maps to expo_rejected.
            def map_http_failure(status_code, attempts:, history:)
              code = status_code.to_i
              error_code =
                if code >= 500 || code == 429
                  submission_uncertain_code
                else
                  "expo_rejected"
                end
              attempts.each { |attempt| attempt.error_code ||= error_code if attempt.submitted }
              carried = error_code == submission_uncertain_code ? [] : carried_accepted_entries(history)

              AdapterResult.build(
                outcome: :terminal_failure,
                error_code:,
                provider_metadata: provider_metadata_for(attempts, carried:),
              )
            end

            # Delivery-wide aggregation: this attempt's endpoints plus tickets recorded earlier.
            def aggregate_result(attempts, history:)
              submitted = attempts.select(&:submitted)
              successes = attempts.select { |attempt| attempt.outcome == :success }
              first_ticket_id = successes.filter_map { |attempt| attempt.ticket&.dig(:id) }.first
              metadata = provider_metadata_for(attempts)

              if submitted.any? { |attempt| attempt.outcome == :success } &&
                 submitted.any? do |attempt|
                   attempt.outcome == :terminal_failure && attempt.error_code == submission_uncertain_code
                 end
                return AdapterResult.build(
                  outcome: :terminal_failure,
                  error_code: submission_uncertain_code,
                  provider_message_id: first_ticket_id,
                  provider_metadata: metadata,
                )
              end

              if attempts.any? { |attempt| attempt.outcome == :retryable_failure }
                return AdapterResult.build(
                  outcome: :terminal_failure,
                  error_code: submission_uncertain_code,
                  provider_message_id: first_ticket_id,
                  provider_metadata: metadata,
                )
              end

              if successes.any? || history.accepted?
                return AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: "accepted",
                  provider_message_id: first_ticket_id || history.first_accepted_ticket_id,
                  provider_metadata: metadata,
                )
              end

              if attempts.all? { |attempt| attempt.outcome == :terminal_failure }
                error_code = attempts.filter_map(&:error_code).first ||
                  history.first_terminal_error_code ||
                  "expo_rejected"
                return AdapterResult.build(outcome: :terminal_failure, error_code:, provider_metadata: metadata)
              end

              AdapterResult.build(
                outcome: :terminal_failure,
                error_code: submission_uncertain_code,
                provider_metadata: metadata,
              )
            end

            def not_submitted_result(_attempts, history: nil)
              AdapterResult.build(
                outcome: :retryable_failure,
                error_code: "expo_not_submitted",
                provider_metadata: {
                  "submission" => Messaging::DeliveryRetryPolicy::SUBMISSION_NOT_SUBMITTED,
                },
              )
            end

            def uncertain_terminal_result(attempts, history:)
              metadata = provider_metadata_for(attempts)
              metadata = metadata.merge("submission" => submission_uncertain_code) if metadata.is_a?(Hash)

              AdapterResult.build(
                outcome: :terminal_failure,
                error_code: submission_uncertain_code,
                provider_metadata: metadata,
              )
            end

            def submission_uncertain_code
              Messaging::DeliveryRetryPolicy::SUBMISSION_UNCERTAIN
            end

            def carried_accepted_entries(history)
              history.accepted_ticket_ids.map do |endpoint_id, ticket_id|
                entry = { "endpoint_id" => endpoint_id, "ticket_status" => "ok" }
                entry["ticket_id"] = ticket_id if ticket_id.present?
                entry
              end
            end

            # Per-device facts as recorded so far. Endpoints never submitted to Expo carry
            # no ticket or receipt status. No tokens, bodies, or exceptions are included.
            def provider_metadata_for(attempts, carried: [])
              return nil unless attempts.is_a?(Array) && attempts.any?(&:submitted)

              { "expo" => { "endpoints" => attempts.map { |attempt| endpoint_metadata(attempt) } + carried } }
            end

            def endpoint_metadata(attempt)
              entry = { "endpoint_id" => attempt.endpoint_id }
              if attempt.submitted
                ticket_id = attempt.ticket&.dig(:id)
                entry["ticket_id"] = ticket_id if ticket_id.present?
                entry["ticket_status"] = ticket_status_for(attempt)
                entry["receipt_status"] = receipt_status_for(attempt)
              end
              entry["error_code"] = attempt.error_code if attempt.error_code.present?
              entry
            end

            def ticket_status_for(attempt)
              case attempt.ticket&.dig(:status)
              when "ok" then "ok"
              when "error" then "error"
              else "missing"
              end
            end

            def receipt_status_for(attempt)
              return "unchecked" unless ticket_status_for(attempt) == "ok"

              case attempt.receipt&.dig(:status)
              when "ok" then "ok"
              when "error" then "error"
              else "pending"
              end
            end
          end
        end
      end
    end
  end
end
