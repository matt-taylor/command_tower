# frozen_string_literal: true

module CommandTower
  module Messaging
    module Handoff
      class Recovery
        GRACE_WINDOW = 1.minute

        def self.call(grace_window: GRACE_WINDOW)
          new(grace_window:).call
        end

        def initialize(grace_window: GRACE_WINDOW)
          @grace_window = grace_window
        end

        def call
          Messaging::Communication.needing_handoff_recovery(grace_before: @grace_window.ago).find_each do |communication|
            Messaging::HandoffJob.perform_later(communication.id)
            OperationLogger.recovered(communication:)
          end
        end
      end
    end
  end
end
