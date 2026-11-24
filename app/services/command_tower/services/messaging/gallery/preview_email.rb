# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # The email channel of a gallery preview: the HTML and text `DefinedEmailRenderer` produces
        # from the fixture, plus whether it fell back from the composed document.
        module PreviewEmail
          # Stand-in for the row `DefinedEmailRenderer` expects. Built from the fixture, never read.
          Subject = Data.define(
            :id, :notification_type_key, :metadata, :metadata_version, :slots, :render_zone, :title, :body
          )

          module_function

          # @param context [Messaging::Definitions::RenderContext] with slots resolved
          # @return [Hash] `subject`, `html`, `text`, `used_fallback`
          def call(definition:, context:)
            output = ChannelFailed.guard("email") do
              CommandTower::Messaging::Rendering::DefinedEmailRenderer.render(
                communication: subject_for(context), definition:
              )
            end
            { subject: (context.slots[:subject] || context.slots[:headline]).to_s, html: output.html,
              text: output.text, used_fallback: fallback?(definition, context) }
          end

          def subject_for(context)
            Subject.new(
              id: nil, notification_type_key: context.notification_type_key, metadata: context.metadata,
              metadata_version: context.metadata_version, slots: context.slots,
              render_zone: context.render_zone, title: context.slots[:headline].to_s, body: ""
            )
          end

          # True when the composed email document cannot be built or rendered (a composer error, a
          # missing fact block or a `code` node), which is when `DefinedEmailRenderer` falls back.
          def fallback?(definition, context)
            document = CommandTower::Messaging::Definitions::DocumentBuilder.email(
              definition: definition.new, context:
            )
            CommandTower::UI::Email::Renderer.call(
              document, palette: CommandTower::EmailTheme::Palette.resolve,
                        origin: CommandTower.config.application.composed_url, user_zone: context.render_zone
            )
            false
          rescue StandardError
            true
          end
        end
      end
    end
  end
end
