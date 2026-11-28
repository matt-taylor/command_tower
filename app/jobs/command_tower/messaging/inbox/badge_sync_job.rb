# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Sets the recipient's app icon badge with a silent, badge-only push. Takes the user id only;
      # the count and device tokens are read when the job runs.
      class BadgeSyncJob < CommandTower::ApplicationJob
        queue_as :messaging_handoff

        def perform(user_id)
          CommandTower::Workflows::Messaging::Inbox::SyncAppIconBadgeWorkflow.call_from_job(
            job: self,
            user_id:
          )
        end
      end
    end
  end
end
