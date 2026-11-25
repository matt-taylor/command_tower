# frozen_string_literal: true

module CommandTower
  module Auth
    module EmailVerification
      # Generates and emails an email-verification code off the request path. The
      # only argument is the user id; the code is generated inside the job and
      # never travels through the queue or its logs.
      class IssueJob < CommandTower::ApplicationJob
        queue_as :default

        self.log_arguments = false

        def perform(user_id)
          CommandTower::Workflows::Auth::EmailVerification::IssueWorkflow.call_from_job(
            job: self,
            user_id: user_id
          )
        end
      end
    end
  end
end
