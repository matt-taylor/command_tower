# frozen_string_literal: true

module CommandTower
  module Messaging
    class HandoffRecoveryJob < CommandTower::ApplicationJob
      queue_as :messaging_handoff_recovery

      def perform
        Handoff::Recovery.call
      end
    end
  end
end
