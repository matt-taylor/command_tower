# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module ScopeResolution
        module_function

        def resolve(tool_id:, user:, scope_value:)
          CommandTower::AdminScope::Resolve.call(tool_id:, principal: user, scope_value:)
        rescue CommandTower::Errors::ForbiddenError => error
          CommandTower::Workflows::WorkflowResult.failure(errors: [error], http_status: :forbidden)
        end
      end
    end
  end
end
