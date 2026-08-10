# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Handoff
        # Job-entry orchestration: advance accepted communications into execution scheduling.
        class ProcessWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :scheduled_cadence

          def call(communication_id:)
            communication = load_communication(communication_id)
            if communication.nil?
              return success(
                payload: { outcome: :noop, reason: :missing },
                http_status: :ok,
              )
            end

            if communication.handoff_terminal?
              return success(
                payload: { outcome: :noop, reason: :terminal, communication_id: communication.id },
                http_status: :ok,
              )
            end

            CommandTower::Messaging::Handoff::OperationLogger.started(communication:)

            begin
              communication = CommandTower::Messaging::Handoff::AdvanceCommunication.call(
                communication:,
              )
              CommandTower::Messaging::Handoff::OperationLogger.succeeded(communication:)
              schedule_execution!(communication)
              success(
                payload: {
                  outcome: :advanced,
                  communication_id: communication.id,
                  execution_handoff_status: communication.execution_handoff_status,
                },
                http_status: :ok,
              )
            rescue StandardError => error
              mark_failed(communication)
              failed = load_communication(communication_id)
              if failed
                CommandTower::Messaging::Handoff::OperationLogger.failed(
                  communication: failed,
                  error:,
                )
              end
              failure(
                errors: [CommandTower::Errors::InternalError.new(cause: error)],
                http_status: :internal_server_error,
                meta: { propagate_to_job: true },
              )
            end
          end

          private

          def schedule_execution!(communication)
            queued_ids = communication.channel_deliveries
              .select { |delivery| delivery.status == CommandTower::Messaging::ChannelDelivery::STATUS_QUEUED }
              .map(&:id)

            CommandTower::Messaging::Execution::Scheduler.schedule_after_commit(queued_ids)
          end

          def load_communication(communication_id)
            CommandTower::Messaging::Communication.includes(:channel_deliveries, :inbox_item).find_by(
              id: communication_id,
            )
          end

          def mark_failed(communication)
            return if communication.nil?
            return if communication.handoff_terminal?

            communication.update(
              execution_handoff_status: CommandTower::Messaging::Communication::HANDOFF_FAILED,
            )
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
