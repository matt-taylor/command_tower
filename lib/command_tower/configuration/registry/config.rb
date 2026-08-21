# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/registry/audit/config"
require "command_tower/configuration/registry/admin_workspace/config"
require "command_tower/configuration/registry/principal_capabilities/config"

module CommandTower
  module Configuration
    module Registry
      class Config
        include ClassComposer::Generator

        add_composer :audit,
          desc: "Registered semantic audit event policy (CommandTower-owned and host-owned names)",
          allowed: Audit::Config,
          dynamic_default: ->(_) { Audit::Config.new },
          default_shown: "Audit::Config.new"

        add_composer :admin_workspace,
          desc: "Registered Admin Workspace tools (CommandTower-owned and host-owned)",
          allowed: AdminWorkspace::Config,
          dynamic_default: ->(_) { AdminWorkspace::Config.new },
          default_shown: "AdminWorkspace::Config.new"

        add_composer :principal_capabilities,
          desc: "Curated frontend-projectable principal capabilities (CommandTower-owned and host-owned)",
          allowed: PrincipalCapabilities::Config,
          dynamic_default: ->(_) { PrincipalCapabilities::Config.new },
          default_shown: "PrincipalCapabilities::Config.new"
      end
    end
  end
end
