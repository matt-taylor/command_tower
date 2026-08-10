# frozen_string_literal: true

module CommandTower
  module Messaging
    class ExecutionRecoveryJob < CommandTower::ApplicationJob
      queue_as :messaging_execution_recovery

      def perform
        Execution::Recovery.call
      end
    end
  end
end
