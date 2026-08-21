# frozen_string_literal: true

module CommandTower
  module PrincipalCapabilitiesSpecHelper
    DUMMY_CAPABILITY_ID = "dummy_admin_example"

    def reset_host_principal_capabilities!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.principal_capabilities.reset_host_definitions!
      restore_dummy_principal_capability!
    end

    def restore_dummy_principal_capability!
      return unless defined?(FoundationProof::WorkspaceExampleController)
      return if CommandTower.config.registry.principal_capabilities.registered?(DUMMY_CAPABILITY_ID)

      CommandTower.config.registry.principal_capabilities.capability :dummy_admin_example
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::PrincipalCapabilitiesSpecHelper
  config.before { restore_dummy_principal_capability! }
  config.after { reset_host_principal_capabilities! }
end
