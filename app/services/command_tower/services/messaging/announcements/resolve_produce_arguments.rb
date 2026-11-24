# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Announcements
        # Decides how an admin announcement is handed to the Produce family (design D26).
        #
        # - Undefined or unregistered type: title, body and metadata pass through unchanged.
        # - Type defined by an `AnnouncementDefinition` (or a subclass): the admin title and body
        #   become metadata (`title`, `body_markdown`) and no title or body is produced. Metadata that
        #   fails the definition's schema is a `ValidationError` naming attributes only.
        # - Any other defined type: fails with `AnnouncementTypeNotSupportedError` (HTTP 422).
        #
        # Outputs: `title`, `body`, `metadata`.
        class ResolveProduceArguments < CommandTower::Services::ApplicationService
          validate :notification_type_key, is_a: String, required: true
          validate :title, is_a: String, required: false
          validate :body, is_a: String, required: false
          validate :metadata, is_a: Hash, required: false

          def call
            definition = definition_class
            return pass_through if definition.nil?

            unless definition <= CommandTower::Messaging::AnnouncementDefinition
              context.fail!(application_error: CommandTower::Errors::Messaging::AnnouncementTypeNotSupportedError.new)
              return
            end

            map_into_metadata(definition)
          end

          private

          def definition_class
            return nil unless CommandTower::Messaging::NotificationTypes.registered?(notification_type_key)

            klass = CommandTower::Messaging::NotificationTypes.lookup(notification_type_key).message&.safe_constantize
            klass if klass.is_a?(Class) && klass < CommandTower::Messaging::MessageDefinition
          end

          def pass_through
            context.title = title
            context.body = body
            context.metadata = metadata
          end

          def map_into_metadata(definition)
            mapped = mapped_metadata
            invalid = definition.metadata_schema.schema_errors(mapped)
            return fail_invalid(invalid) if invalid.any?

            context.title = nil
            context.body = nil
            context.metadata = mapped
          end

          def mapped_metadata
            (metadata || {}).to_h.transform_keys(&:to_s).merge("title" => title, "body_markdown" => body)
          end

          def fail_invalid(invalid)
            context.fail!(
              application_error: CommandTower::Errors::ValidationError.new(
                details: { messaging: "announcement is invalid (attributes: #{invalid.join(', ')})" }
              )
            )
          end
        end
      end
    end
  end
end
