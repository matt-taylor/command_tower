# frozen_string_literal: true

module CommandTower
  module Admin
    class WorkspaceController < CommandTower::Admin::ApplicationController
      skip_before_action :reject_admin_operations_during_impersonation!, only: :show

      def show
        render_application_result(
          CommandTower::Workflows::Admin::Workspace::ManifestWorkflow.call(user: current_user)
        )
      end
    end
  end
end
