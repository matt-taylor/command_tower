# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class IdentityPolicyWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call
          policy_result = CommandTower::Services::Auth::IdentityPolicy.call

          unless policy_result.success?
            return failure(errors: policy_result.errors, http_status: :internal_server_error)
          end

          success(
            payload: CommandTower::Serializers::Auth::IdentityPolicySerializer.serialize(
              policy: policy_result.data[:policy]
            ),
            http_status: :ok
          )
        end
      end
    end
  end
end
