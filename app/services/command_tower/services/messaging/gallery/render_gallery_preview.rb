# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Renders one declared fixture of one defined notification type through every channel the
        # type allows, with the same pure code the sender and the inbox read use (design 3.5).
        #
        # - Data comes only from the definition's declared fixtures. It takes no communication id and
        #   reads no `Communication`.
        # - `fixture` is a declared fixture name (default: the first). An unknown name is NotFound.
        # - `zone` is any valid TZInfo identifier (default: the definition's `default_zone`) and acts as
        #   the render zone. An invalid identifier is a ValidationError.
        # - A channel the type does not allow is nil (`inbox` included, G16).
        # - A composer that raises fails the preview with the channel and error class only; metadata
        #   values never reach errors.
        #
        # `footer_notice` (optional) is a line above the email's compliance footer; only the test send sets it.
        #
        # Output: `preview` (snake_case Hash; the serializer shapes the wire form).
        class RenderGalleryPreview < CommandTower::Services::ApplicationService
          validate :notification_type_key, is_a: String, required: true
          validate :fixture, is_a: String, required: false
          validate :zone, is_a: String, required: false
          validate :footer_notice, is_a: String, required: false

          def call
            target = resolve_target
            return not_found unless target

            render_zone = render_zone_for(target[:definition])
            return invalid_zone unless TZInfo::Timezone.all_identifiers.include?(render_zone)

            context.preview = PreviewBuilder.call(**target, render_zone:, footer_notice:)
          rescue ChannelFailed => e
            fail_channel(e)
          end

          private

          # @return [Hash, nil] `declaration`, `definition`, `fixture`; nil when any is not found
          def resolve_target
            return unless CommandTower::Messaging::NotificationTypes.registered?(notification_type_key)

            declaration = CommandTower::Messaging::NotificationTypes.lookup(notification_type_key)
            definition = definition_for(declaration)
            name = definition && fixture_name(definition)
            { declaration:, definition:, fixture: name } if name
          end

          def definition_for(declaration)
            klass = declaration.message&.safe_constantize
            klass if klass.is_a?(Class) && klass < CommandTower::Messaging::MessageDefinition
          end

          def fixture_name(definition)
            name = fixture.presence || definition.fixtures.keys.first
            name if definition.fixtures.key?(name)
          end

          def render_zone_for(definition)
            zone.presence || definition.default_zone.presence || CommandTower.config.ui.default_zone
          end

          def not_found
            context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
          end

          def invalid_zone
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(
              details: { zone: "is not a valid time zone" }
            ))
          end

          def fail_channel(error)
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(
              details: { gallery: "preview failed (channel: #{error.channel}, error: #{error.error_class})" }
            ))
          end
        end
      end
    end
  end
end
