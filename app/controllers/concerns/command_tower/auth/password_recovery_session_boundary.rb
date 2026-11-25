# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordRecoverySessionBoundary
      extend ActiveSupport::Concern
      include CommandTower::Auth::LegacyContractBoundary

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
        record_legacy_contract_use("authorization_scheme.recovery")
        true
      end
    end
  end
end
