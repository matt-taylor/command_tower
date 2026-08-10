# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      class HandoffScheduler
        def self.schedule_after_commit(communication_id)
          new(communication_id).schedule_after_commit
        end

        def self.enqueue(communication_id)
          new(communication_id).enqueue
        end

        def initialize(communication_id)
          @communication_id = communication_id
        end

        def schedule_after_commit
          ActiveRecord.after_all_transactions_commit { enqueue }
        end

        def enqueue
          Messaging::HandoffJob.perform_later(@communication_id)
          communication = Messaging::Communication.find_by(id: @communication_id)
          if communication
            Handoff::OperationLogger.scheduled(communication:)
          end
        rescue StandardError => error
          Handoff::OperationLogger.enqueue_failed(
            communication_id: @communication_id,
            error:,
          )
          # Leave execution_handoff_status as pending — recovery will redrive.
          nil
        end
      end
    end
  end
end
