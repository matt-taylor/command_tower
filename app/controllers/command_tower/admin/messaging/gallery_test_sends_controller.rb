# frozen_string_literal: true

module CommandTower
  module Admin
    module Messaging
      # Gallery test send: emails one fixture to the real actor's own address. It has its own
      # controller because the role check requires every entity mapped to a controller to approve
      # each of its actions, so it cannot share `GalleryController` with `admin_messaging_gallery`.
      #
      # Impersonation is refused here with `gallery_test_send_impersonating` (403), ahead of
      # authorization (which would judge the impersonated user), not with the generic admin 418.
      class GalleryTestSendsController < CommandTower::Admin::ApplicationController
        skip_before_action :reject_admin_operations_during_impersonation!
        skip_before_action :authorize_request!
        before_action :refuse_impersonation!
        before_action :authorize_request!
        prepend_before_action :set_no_store

        def create
          render_application_result(
            CommandTower::Workflows::Admin::Messaging::Gallery::TestSendWorkflow.call(
              actor: current_auth_context.actor_user,
              effective_user: current_user,
              notification_type_key: params[:notification_type_key].to_s,
              fixture: params[:fixture].presence&.to_s,
              zone: params[:zone].presence&.to_s
            )
          )
        end

        private

        def refuse_impersonation!
          return unless impersonating_or_not_actor?

          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [CommandTower::Errors::Messaging::GalleryTestSendImpersonatingError.new],
              http_status: :forbidden
            )
          )
        end

        def impersonating_or_not_actor?
          CommandTower::Current.impersonation_active || current_auth_context.actor_user&.id != current_user.id
        end

        def set_no_store
          response.set_header("Cache-Control", "no-store")
        end
      end
    end
  end
end
