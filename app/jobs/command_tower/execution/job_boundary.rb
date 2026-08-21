# frozen_string_literal: true

module CommandTower
  module Execution
    module JobBoundary
      extend ActiveSupport::Concern

      included do
        around_perform :command_tower_job_execution
      end

      private

      def command_tower_job_execution
        CommandTower.with_execution(source: :job) { yield }
      end
    end
  end
end
