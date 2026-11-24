# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Messaging
        module Gallery
          # Previews one fixture of one defined notification type across every allowed channel.
          # Authorization is the controller's RBAC boundary (entity `admin_messaging_gallery`).
          class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
            retry_strategy :none

            def call(notification_type_key:, fixture: nil, zone: nil)
              rendered = CommandTower::Services::Messaging::Gallery::RenderGalleryPreview.call(
                notification_type_key:, fixture:, zone:
              )
              return rendered_failure(rendered) unless rendered.success?

              success(
                payload: CommandTower::Serializers::Admin::Messaging::GallerySerializer.serialize_preview(
                  rendered.data[:preview]
                ),
                http_status: :ok
              )
            end

            private

            def rendered_failure(rendered)
              failure(
                errors: rendered.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(rendered.errors.first)
              )
            end
          end
        end
      end
    end
  end
end
