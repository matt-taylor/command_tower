# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Messaging
        module Gallery
          # Lists the notification types the gallery can preview. Authorization is the controller's
          # RBAC boundary (entity `admin_messaging_gallery`).
          class IndexWorkflow < CommandTower::Workflows::ApplicationWorkflow
            retry_strategy :none

            def call
              listed = CommandTower::Services::Messaging::Gallery::ListGalleryTypes.call
              return failure(errors: listed.errors, http_status: :internal_server_error) unless listed.success?

              success(
                payload: CommandTower::Serializers::Admin::Messaging::GallerySerializer.serialize_list(
                  listed.data[:types]
                ),
                http_status: :ok
              )
            end
          end
        end
      end
    end
  end
end
