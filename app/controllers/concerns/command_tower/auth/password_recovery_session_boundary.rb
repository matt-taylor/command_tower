# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordRecoverySessionBoundary
      extend ActiveSupport::Concern

      included do
        include CommandTower::Api::ApplicationResponseRenderer

        attr_reader :current_password_recovery_session
      end

      private

      def authenticate_password_recovery_session!
        result = CommandTower::Workflows::Auth::PasswordRecoverySession::AuthenticateWorkflow.call(request: request)

        unless result.success?
          render_application_result(result)
          return false
        end

        @current_password_recovery_session = result.payload[:password_recovery_session]
        true
      end
    end
  end
end
