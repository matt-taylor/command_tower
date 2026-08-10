# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Preferences
        class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:)
            result = CommandTower::Services::Messaging::Preferences::Show.call(user:)

            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(error)
              )
            end

            payload = CommandTower::Serializers::Messaging::Preferences::CatalogSerializer.serialize(
              result.data[:catalog],
            )

            success(payload:, http_status: :ok)
          end
        end
      end
    end
  end
end
