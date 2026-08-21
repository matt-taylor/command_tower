# frozen_string_literal: true

module CommandTower
  class ApplicationJob < ActiveJob::Base
    include CommandTower::Execution::JobBoundary

    def execute_workflow(workflow_class, **args)
      workflow_class.call_from_job(job: self, **args)
    end
  end
end
