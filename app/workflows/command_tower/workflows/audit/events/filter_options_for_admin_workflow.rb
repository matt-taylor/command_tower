# frozen_string_literal: true

module CommandTower
  module Workflows
    module Audit
      module Events
        class FilterOptionsForAdminWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call
            projected = CommandTower::Services::Audit::Events::FilterOptions.call(viewer_scope: :admin)
            return result_or_failure(projected) unless projected.success?

            payload = CommandTower::Serializers::Audit::Events::FilterOptionsSerializer.serialize(
              event_names: projected.data[:event_names],
              subject_types: projected.data[:subject_types],
              attribution_modes: projected.data[:attribution_modes]
            )
            success(payload:, http_status: :ok)
          end

          private

          def result_or_failure(result)
            failure(
              errors: result.errors,
              http_status: CommandTower::Workflows::Audit::ErrorMapping.http_status_for(result.errors.first)
            )
          end
        end
      end
    end
  end
end
