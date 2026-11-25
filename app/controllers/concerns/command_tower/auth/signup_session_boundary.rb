# frozen_string_literal: true

module CommandTower
  module Auth
    module SignupSessionBoundary
      extend ActiveSupport::Concern
      include CommandTower::Auth::LegacyContractBoundary

      included do
        include CommandTower::Api::ApplicationResponseRenderer

        attr_reader :current_signup_session
      end

      private

      def authenticate_signup_session!
        result = CommandTower::Workflows::Auth::SignupSession::AuthenticateWorkflow.call(request: request)

        unless result.success?
          render_application_result(result)
          return false
        end

        @current_signup_session = result.payload[:signup_session]
        record_legacy_contract_use("authorization_scheme.signup")
        true
      end
    end
  end
end
