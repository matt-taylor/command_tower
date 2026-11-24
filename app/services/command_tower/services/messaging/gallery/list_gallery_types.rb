# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Lists the notification types the admin gallery can preview: registered types whose
        # declaration names a `MessageDefinition`. Reads the registry and the definition classes
        # only. It touches no `Communication` and no user data.
        #
        # Output: `types`, an Array of Hashes with `notification_type_key`, `label`, `definition`
        # (class name), `allowed_channels`, `promotional` and `fixtures` (`name`, `metadata_version`).
        class ListGalleryTypes < CommandTower::Services::ApplicationService
          def call
            context.types = CommandTower::Messaging::NotificationTypes.enumerate.filter_map do |declaration|
              definition = definition_for(declaration)
              project(declaration, definition) if definition
            end
          end

          private

          def definition_for(declaration)
            klass = declaration.message&.safe_constantize
            klass if klass.is_a?(Class) && klass < CommandTower::Messaging::MessageDefinition
          end

          def project(declaration, definition)
            {
              notification_type_key: declaration.key,
              label: declaration.label,
              definition: definition.name,
              allowed_channels: declaration.allowed_channels.to_a,
              promotional: definition.promotional?,
              fixtures: definition.fixtures.keys.map do |name|
                { name:, metadata_version: definition.metadata_version }
              end
            }
          end
        end
      end
    end
  end
end
