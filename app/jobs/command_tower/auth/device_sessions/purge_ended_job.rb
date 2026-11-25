# frozen_string_literal: true

module CommandTower
  module Auth
    module DeviceSessions
      # Scheduled by the host (see authentication.md). Takes no arguments.
      class PurgeEndedJob < CommandTower::ApplicationJob
        queue_as :default

        def perform
          CommandTower::Workflows::Auth::DeviceSessions::PurgeEndedWorkflow.call_from_job(job: self)
        end
      end
    end
  end
end
