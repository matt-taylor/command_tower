# frozen_string_literal: true

module CommandTower
  module Auth
    module AuthorizationBoundary
      extend ActiveSupport::Concern

      private

      def authorize_request!
        result = CommandTower::Workflows::Auth::AuthorizeRequestWorkflow.call(
          current_user: current_user,
          controller_class: self.class,
          action_name: action_name
        )

        unless result.success?
          render_application_result(result)
          return false
        end

        true
      end
    end
  end
end
