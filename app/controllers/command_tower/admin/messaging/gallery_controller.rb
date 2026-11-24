# frozen_string_literal: true

module CommandTower
  module Admin
    module Messaging
      # Admin message gallery: previews every channel of each defined notification type from its
      # declared fixtures. Index and show need the RBAC entity `admin_messaging_gallery`. The test
      # send (slice 13) lives in `GalleryTestSendsController` under its own entity. Responses are
      # `no-store`.
      class GalleryController < CommandTower::Admin::ApplicationController
        prepend_before_action :set_no_store

        def index
          render_application_result(CommandTower::Workflows::Admin::Messaging::Gallery::IndexWorkflow.call)
        end

        def show
          render_application_result(
            CommandTower::Workflows::Admin::Messaging::Gallery::ShowWorkflow.call(
              notification_type_key: params[:notification_type_key].to_s,
              fixture: params[:fixture].presence&.to_s,
              zone: params[:zone].presence&.to_s
            )
          )
        end

        private

        def set_no_store
          response.set_header("Cache-Control", "no-store")
        end
      end
    end
  end
end
