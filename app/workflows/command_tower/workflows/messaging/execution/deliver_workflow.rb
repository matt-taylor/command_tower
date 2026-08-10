# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Execution
        # Job-entry orchestration for a single channel delivery attempt.
        class DeliverWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(channel_delivery_id:, executor: nil)
            delivery = load_delivery(channel_delivery_id)
            if delivery.nil?
              return success(payload: { outcome: :noop, reason: :missing }, http_status: :ok)
            end

            if delivery.execution_terminal?
              return success(
                payload: { outcome: :noop, reason: :terminal, channel_delivery_id: delivery.id },
                http_status: :ok,
              )
            end

            unless CommandTower::Messaging::Execution::Claim.call(delivery:)
              return success(
                payload: { outcome: :noop, reason: :claim_lost, channel_delivery_id: delivery.id },
                http_status: :ok,
              )
            end

            delivery.reload
            ledger = CommandTower::Messaging::Execution::AttemptLedger.new
            CommandTower::Messaging::Execution::OperationLogger.claimed(channel_delivery: delivery)
            CommandTower::Messaging::Execution::OperationLogger.started(channel_delivery: delivery)

            attempt = ledger.start(delivery:)
            if attempt.nil?
              return success(
                payload: { outcome: :retryable, reason: :attempt_create_failed, channel_delivery_id: delivery.id },
                http_status: :ok,
              )
            end

            begin
              communication = delivery.communication
              readiness = CommandTower::Messaging::Execution::RevalidateReadiness.call(
                delivery:,
                attempt:,
                communication:,
              )
              if readiness.is_a?(String)
                ledger.finalize_terminal(delivery:, attempt:, error_code: readiness)
                return success(
                  payload: { outcome: :terminal, channel_delivery_id: delivery.id, error_code: readiness },
                  http_status: :ok,
                )
              end

              resolution = CommandTower::Messaging::Execution::ResolveRecipientAddress.call(
                communication:,
                channel_key: delivery.channel_key,
                readiness_result: readiness,
              )

              if resolution[:error_code]
                ledger.finalize_terminal(delivery:, attempt:, error_code: resolution[:error_code])
                return success(
                  payload: {
                    outcome: :terminal,
                    channel_delivery_id: delivery.id,
                    error_code: resolution[:error_code],
                  },
                  http_status: :ok,
                )
              end

              recipient_address = resolution[:address]

              unless CommandTower::Messaging::Rendering::ChannelRenderer.supported_channel?(delivery.channel_key)
                ledger.finalize_terminal(delivery:, attempt:, error_code: "adapter_unconfigured")
                return success(
                  payload: {
                    outcome: :terminal,
                    channel_delivery_id: delivery.id,
                    error_code: "adapter_unconfigured",
                  },
                  http_status: :ok,
                )
              end

              if blank_recipient?(recipient_address)
                ledger.finalize_terminal(delivery:, attempt:, error_code: "recipient_missing")
                return success(
                  payload: {
                    outcome: :terminal,
                    channel_delivery_id: delivery.id,
                    error_code: "recipient_missing",
                  },
                  http_status: :ok,
                )
              end

              rendered = render_payload!(delivery, attempt, communication, recipient_address, ledger)
              if rendered.nil?
                return success(
                  payload: { outcome: :terminal, channel_delivery_id: delivery.id, error_code: :render_failed },
                  http_status: :ok,
                )
              end

              request = CommandTower::Messaging::Execution::AdapterRequest.build(
                channel_delivery_id: delivery.id,
                communication_id: delivery.communication_id,
                channel_key: delivery.channel_key,
                attempt_id: attempt.id,
                rendered:,
              )
              adapter = CommandTower::Messaging::Execution::SelectAdapter.call(delivery:, executor:)
              CommandTower::Messaging::Execution::OperationLogger.adapter_started(
                channel_delivery: delivery,
                delivery_attempt: attempt,
              )
              result = adapter.call(request:)
              unless result.is_a?(CommandTower::Messaging::Execution::AdapterResult)
                ledger.finalize_unexpected(delivery:, attempt:, error_class: result.class.name)
                return success(
                  payload: { outcome: :retryable, channel_delivery_id: delivery.id },
                  http_status: :ok,
                )
              end

              log_adapter_outcome!(delivery, attempt, result)
              ledger.finalize_from_adapter(delivery:, attempt:, result:)
              delivery.reload
              success(
                payload: {
                  outcome: outcome_for(result),
                  channel_delivery_id: delivery.id,
                  status: delivery.status,
                },
                http_status: :ok,
              )
            rescue StandardError => error
              ledger.finalize_unexpected(delivery:, attempt:, error:)
              success(
                payload: { outcome: :retryable, channel_delivery_id: delivery.id },
                http_status: :ok,
              )
            end
          end

          private

          def load_delivery(channel_delivery_id)
            CommandTower::Messaging::ChannelDelivery.includes(
              communication: %i[user destination_plan],
            ).find_by(id: channel_delivery_id)
          end

          def blank_recipient?(recipient_address)
            recipient_address.nil? || recipient_address.to_s.strip.empty?
          end

          def render_payload!(delivery, attempt, communication, recipient_address, ledger)
            CommandTower::Messaging::Execution::OperationLogger.render_started(
              channel_delivery: delivery,
              delivery_attempt: attempt,
            )

            rendered = CommandTower::Messaging::Rendering::ChannelRenderer.render(
              communication:,
              channel_key: delivery.channel_key,
              recipient_address:,
            )

            CommandTower::Messaging::Execution::OperationLogger.render_succeeded(
              channel_delivery: delivery,
              delivery_attempt: attempt,
            )
            rendered
          rescue CommandTower::Messaging::Rendering::RenderError => error
            CommandTower::Messaging::Execution::OperationLogger.render_failed(
              channel_delivery: delivery,
              delivery_attempt: attempt,
              error_code: error.code,
              error_class: error.error_class,
            )
            ledger.finalize_terminal(delivery:, attempt:, error_code: error.code)
            nil
          rescue StandardError => error
            CommandTower::Messaging::Execution::OperationLogger.render_failed(
              channel_delivery: delivery,
              delivery_attempt: attempt,
              error_code: "render_failed",
              error_class: error.class.name,
            )
            ledger.finalize_terminal(delivery:, attempt:, error_code: "render_failed")
            nil
          end

          def log_adapter_outcome!(delivery, attempt, result)
            if result.success?
              CommandTower::Messaging::Execution::OperationLogger.adapter_accepted(
                channel_delivery: delivery,
                delivery_attempt: attempt,
              )
            elsif result.retryable_failure?
              CommandTower::Messaging::Execution::OperationLogger.adapter_retryable(
                channel_delivery: delivery,
                delivery_attempt: attempt,
                error_code: result.error_code,
              )
            else
              CommandTower::Messaging::Execution::OperationLogger.adapter_terminal(
                channel_delivery: delivery,
                delivery_attempt: attempt,
                error_code: result.error_code,
              )
            end
          end

          def outcome_for(result)
            case result.outcome
            when :success then :delivered
            when :retryable_failure then :retryable
            when :terminal_failure then :terminal
            else result.outcome
            end
          end
        end
      end
    end
  end
end
