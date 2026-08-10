# frozen_string_literal: true

module CommandTower
  module Auth
    module AuthenticationBoundary
      extend ActiveSupport::Concern

      included do
        include CommandTower::Api::ApplicationResponseRenderer

        attr_reader :current_user, :current_auth_context
      end

      private

      def authenticate_request!(bypass_email_validation: false)
        result = CommandTower::Workflows::Auth::AuthenticateRequestWorkflow.call(
          request: request,
          response: response,
          bypass_email_validation: bypass_email_validation
        )

        unless result.success?
          render_application_result(result)
          return false
        end

        @current_user = result.payload[:current_user]
        @current_auth_context = result.payload[:auth_context]
        true
      end
    end
  end
end
