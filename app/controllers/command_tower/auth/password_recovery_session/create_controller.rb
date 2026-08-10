# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordRecoverySession
      class CreateController < CommandTower::ApplicationController
        include CommandTower::Api::ApplicationResponseRenderer

        def create
          client_ip = CommandTower::Services::Auth::ClientIpResolver.call(request: request)
          result = CommandTower::Workflows::Auth::PasswordRecoverySession::CreateWorkflow.call(client_ip: client_ip)
          render_application_result(result)
        end
      end
    end
  end
end
