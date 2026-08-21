# frozen_string_literal: true

module CommandTower
  module AdminWorkspaceSpecHelper
    DUMMY_TOOL_ID = "dummy_admin_example"

    def reset_host_admin_workspace_tools!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.admin_workspace.reset_host_definitions!
      restore_dummy_admin_example_tool!
    end

    def restore_dummy_admin_example_tool!
      return unless defined?(FoundationProof::WorkspaceExampleController)
      return if CommandTower.config.registry.admin_workspace.registered?(DUMMY_TOOL_ID)

      CommandTower.config.registry.admin_workspace.tool :dummy_admin_example do |tool|
        tool.label = "Dummy example"
        tool.description = "Example host Admin tool for registry and manifest proofs."
        tool.route = "/admin/dummy-example"
        tool.group = :operations
        tool.sort_order = 900
        tool.required_entity = :dummy_admin_example
        tool.icon = "beaker"
      end
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::AdminWorkspaceSpecHelper
  config.before { restore_dummy_admin_example_tool! }
  config.after { reset_host_admin_workspace_tools! }
end
