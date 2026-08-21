# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Workspace
        class ManifestWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:)
            result = CommandTower::Services::Admin::Workspace::Manifest.call(user:)
            unless result.success?
              return failure(errors: result.errors, http_status: :unprocessable_entity)
            end

            success(
              payload: CommandTower::Serializers::Admin::Workspace::ManifestSerializer.serialize(result.data[:tools]),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end
