# frozen_string_literal: true

module CommandTower
  module Admin
    module Messaging
      # Skeleton so the RBAC entity `admin_messaging_gallery_test_send` binds to a real action.
      # The role check requires every entity mapped to a controller to approve each of its actions,
      # so the test send cannot share `GalleryController` with `admin_messaging_gallery`. Route and
      # behavior arrive in slice 13 (`POST /admin/messaging/gallery/:notification_type_key/test-send`).
      class GalleryTestSendsController < CommandTower::Admin::ApplicationController
        def create
          head :not_implemented
        end
      end
    end
  end
end
