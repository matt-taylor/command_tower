# frozen_string_literal: true

module CommandTower
  module Auth
    module SignupSession
      class CreateController < CommandTower::ApplicationController
        include CommandTower::Api::ApplicationResponseRenderer
        include CommandTower::Auth::LegacyContractBoundary

        deprecated_auth_endpoint "signup_session"

        def create
          client_ip = CommandTower::Services::Auth::ClientIpResolver.call(request: request)
          result = CommandTower::Workflows::Auth::SignupSession::CreateWorkflow.call(client_ip: client_ip)
          render_application_result(result)
        end
      end
    end
  end
end
