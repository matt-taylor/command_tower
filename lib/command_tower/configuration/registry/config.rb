# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/registry/audit/config"
require "command_tower/configuration/registry/admin_workspace/config"
require "command_tower/configuration/registry/principal_capabilities/config"
require "command_tower/configuration/registry/client_compatibility/config"
require "command_tower/configuration/registry/inbox_presentations/config"

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

        add_composer :client_compatibility,
          desc: "Registered client-version-compatibility policy (platforms, contracts, entity requirements, bindings)",
          allowed: ClientCompatibility::Config,
          dynamic_default: ->(_) { ClientCompatibility::Config.new },
          default_shown: "ClientCompatibility::Config.new"

        add_composer :inbox_presentations,
          desc: "Registered Inbox presentation capabilities (host-owned; no CommandTower-owned capabilities yet)",
          allowed: InboxPresentations::Config,
          dynamic_default: ->(_) { InboxPresentations::Config.new },
          default_shown: "InboxPresentations::Config.new"
      end
    end
  end
end
