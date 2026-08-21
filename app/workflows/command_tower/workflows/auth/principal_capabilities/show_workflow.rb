# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PrincipalCapabilities
        class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:)
            result = CommandTower::Services::Auth::PrincipalCapabilities::Project.call(user:)
            unless result.success?
              return failure(errors: result.errors, http_status: :unprocessable_entity)
            end

            success(
              payload: CommandTower::Serializers::Auth::PrincipalCapabilitiesSerializer.serialize(
                result.data[:principal_capability_ids]
              ),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end
