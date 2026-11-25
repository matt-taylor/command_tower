# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordReset
      # Issues a reset token and emails it, off the request path. The only
      # argument is the normalized email; the token is generated inside the job
      # and never travels through the queue or its logs.
      class IssueJob < CommandTower::ApplicationJob
        queue_as :default

        self.log_arguments = false

        def perform(normalized_email)
          CommandTower::Workflows::Auth::PasswordReset::IssueWorkflow.call_from_job(
            job: self,
            email: normalized_email
          )
        end
      end
    end
  end
end
