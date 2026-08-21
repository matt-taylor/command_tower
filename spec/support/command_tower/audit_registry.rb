# frozen_string_literal: true

module CommandTower
  module AuditRegistrySpecHelper
    def reset_host_audit_events!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.audit.reset_host_definitions!
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::AuditRegistrySpecHelper
  config.after { reset_host_audit_events! }
end
