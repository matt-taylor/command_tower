# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::AdminWorkspace::Config do
  describe "#tool" do
    context "when CommandTower-owned tools are seeded" do
      subject(:audit) { CommandTower.config.registry.admin_workspace.fetch(:audit) }

      it "registers platform audit metadata" do
        expect(audit.owner).to eq(:command_tower)
        expect(audit.label).to eq("Audit")
        expect(audit.description).to eq("Browse account and administrative audit history.")
        expect(audit.route).to eq("/admin/audit")
        expect(audit.group).to eq("operations")
        expect(audit.sort_order).to eq(100)
        expect(audit.required_entity).to eq("admin_audit_events")
        expect(audit.icon).to eq("history")
      end

      it "registers platform users metadata" do
        expect(CommandTower.config.registry.admin_workspace.fetch(:users)).to have_attributes(
          owner: :command_tower,
          description: "Find and inspect platform user accounts.",
          route: "/admin/users",
          required_entity: "admin_users"
        )
      end

      it "registers platform messaging metadata" do
        expect(CommandTower.config.registry.admin_workspace.fetch(:messaging)).to have_attributes(
          owner: :command_tower,
          description: "Manage platform announcements and administrative messaging.",
          route: "/admin/messaging",
          required_entity: "admin_messaging_announcements"
        )
      end
    end

    context "when a host tool is registered" do
      before do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.description = "Host-supplied launcher copy for a product Admin tool."
          tool.route = "/admin/host-example"
          tool.group = :product
          tool.sort_order = 300
          tool.required_entity = :admin_audit_events
        end
      end

      subject(:definition) { CommandTower.config.registry.admin_workspace.fetch(:host_example) }

      it "composes into the same registry as CommandTower tools" do
        expect(definition.owner).to eq(:host)
        expect(definition.description).to eq("Host-supplied launcher copy for a product Admin tool.")
        expect(CommandTower.config.registry.admin_workspace.fetch(:audit).owner).to eq(:command_tower)
        expect(definition.group).to eq("product")
      end
    end

    context "when the same host tool is registered twice" do
      before do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.route = "/admin/host-example"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.route = "/admin/host-example-2"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::DuplicateToolError, /already registered/)
      end
    end

    context "when a host redefines a CommandTower-owned tool" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :audit do |tool|
          tool.label = "Hijacked"
          tool.route = "/admin/hijacked"
          tool.group = :operations
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::HostOverrideError, /cannot redefine/)
      end
    end

    context "when the tool name is invalid" do
      subject(:invoke) { CommandTower.config.registry.admin_workspace.tool("Audit Explorer") }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::InvalidToolNameError, /invalid admin workspace tool name/)
      end
    end

    context "when the label is missing" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.route = "/admin/host-example"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::InvalidToolDefinitionError, /missing label/)
      end
    end

    context "when the description exceeds the hard maximum" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.description = "x" * 161
          tool.route = "/admin/host-example"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(
          CommandTower::AdminWorkspace::InvalidToolDefinitionError,
          /description exceeds 160 characters/
        )
      end
    end

    context "when the description is blank" do
      before do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.description = "   "
          tool.route = "/admin/host-example"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "normalizes to an empty string" do
        expect(CommandTower.config.registry.admin_workspace.fetch(:host_example).description).to eq("")
      end
    end

    context "when the route is invalid" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.route = "/me/inbox"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::InvalidToolDefinitionError, /invalid route/)
      end
    end

    context "when the required entity is missing" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :host_example do |tool|
          tool.label = "Host example"
          tool.route = "/admin/host-example"
          tool.group = :product
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::InvalidToolDefinitionError, /invalid required_entity/)
      end
    end

    context "when a route is reused" do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :other_example do |tool|
          tool.label = "Other example"
          tool.route = "/admin/audit"
          tool.group = :product
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::DuplicateRouteError, /reuses route/)
      end
    end

    context "when the tool is not registered" do
      subject(:invoke) { CommandTower.config.registry.admin_workspace.fetch(:not_registered) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::UnregisteredToolError, /not registered/)
      end
    end

    context "when the registry is finalized" do
      before { CommandTower.config.registry.admin_workspace.finalize! }

      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.tool :after_freeze do |tool|
          tool.label = "After"
          tool.route = "/admin/after"
          tool.group = :operations
          tool.required_entity = :admin_audit_events
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::FrozenRegistryError, /frozen/)
      end
    end
  end

  describe "#reset_platform_tool_scope_config!" do
    context "when resetting after finalize with scoped platform tools" do
      before do
        CommandTower.config.registry.admin_workspace.configure_tool(:users) do |tool|
          tool.scope_required = true
          tool.scope_parameter = "partition"
          tool.scope_label = "Partition"
        end
        CommandTower.config.registry.admin_workspace.finalize!
        CommandTower.config.registry.admin_workspace.reset_platform_tool_scope_config!
      end

      subject(:users) { CommandTower.config.registry.admin_workspace.fetch(:users) }

      it "restores unfrozen default scope attributes" do
        expect(users.scope_required?).to eq(false)
        expect(users.scope_parameter).to eq("")
        expect(users.scope_label).to eq("")
      end

      it "allows configure_tool after reset" do
        expect {
          CommandTower.config.registry.admin_workspace.configure_tool(:users) do |tool|
            tool.scope_required = true
            tool.scope_parameter = "partition"
            tool.scope_label = "Partition"
          end
        }.not_to raise_error
      end
    end
  end

  describe "#validate_required_entities!" do
    context "when a required entity is not in the RBAC graph" do
      before do
        CommandTower.config.registry.admin_workspace.tool :orphan do |tool|
          tool.label = "Orphan"
          tool.route = "/admin/orphan"
          tool.group = :operations
          tool.required_entity = :does_not_exist
        end
      end

      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.validate_required_entities!(
          CommandTower::Authorization::Entity.entities
        )
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::AdminWorkspace::MissingRequiredEntityError, /does_not_exist/)
      end
    end

    context "when seeded tools match composed entities", :with_rbac_setup do
      subject(:invoke) do
        CommandTower.config.registry.admin_workspace.validate_required_entities!(
          CommandTower::Authorization::Entity.entities
        )
      end

      it "accepts CommandTower-owned required entities" do
        expect(invoke).to eq(CommandTower.config.registry.admin_workspace)
      end
    end
  end
end
