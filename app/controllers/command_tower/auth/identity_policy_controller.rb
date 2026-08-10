# frozen_string_literal: true

module CommandTower
  module Auth
    class IdentityPolicyController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      def show
        result = CommandTower::Workflows::Auth::IdentityPolicyWorkflow.call
        render_application_result(result)
      end
    end
  end
end
