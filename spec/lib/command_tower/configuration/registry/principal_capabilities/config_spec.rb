# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::PrincipalCapabilities::Config do
  describe "#capability" do
    context "when CommandTower-owned capabilities are seeded" do
      subject(:registry) { CommandTower.config.registry.principal_capabilities }

      it "registers the curated Admin and Me projectable catalog" do
        expect(registry.definitions.keys).to include(
          "admin_workspace",
          "admin_audit_events",
          "admin_messaging_announcements",
          "admin_users",
          "admin_users_update",
          "admin_rbac_assignments",
          "admin_impersonation",
          "me_audit_events"
        )
        expect(registry.fetch(:admin_workspace)).to have_attributes(
          owner: :command_tower,
          required_entity: "admin_workspace"
        )
        expect(registry.fetch(:admin_audit_events).required_entity).to eq("admin_audit_events")
        expect(registry.fetch(:admin_messaging_announcements).required_entity).to eq(
          "admin_messaging_announcements"
        )
        expect(registry.fetch(:me_audit_events)).to have_attributes(
          owner: :command_tower,
          required_entity: "me_audit_events"
        )
      end
    end

    context "when a host capability is registered" do
      before do
        CommandTower.config.registry.principal_capabilities.capability :host_example do |capability|
          capability.required_entity = :admin_audit_events
        end
      end

      subject(:definition) { CommandTower.config.registry.principal_capabilities.fetch(:host_example) }

      it "composes into the same registry as CommandTower capabilities" do
        expect(definition.owner).to eq(:host)
        expect(definition.required_entity).to eq("admin_audit_events")
        expect(CommandTower.config.registry.principal_capabilities.fetch(:admin_workspace).owner).to eq(
          :command_tower
        )
      end
    end

    context "when a host redefines a CommandTower capability" do
      subject(:invoke) do
        CommandTower.config.registry.principal_capabilities.capability :admin_workspace
      end

      it "raises HostOverrideError" do
        expect { invoke }.to raise_error(
          CommandTower::PrincipalCapabilities::HostOverrideError,
          /admin_workspace/
        )
      end
    end

    context "when the same host capability is registered twice" do
      before do
        CommandTower.config.registry.principal_capabilities.capability :host_example
      end

      subject(:invoke) do
        CommandTower.config.registry.principal_capabilities.capability :host_example
      end

      it "raises DuplicateCapabilityError" do
        expect { invoke }.to raise_error(
          CommandTower::PrincipalCapabilities::DuplicateCapabilityError,
          /host_example/
        )
      end
    end

    context "when the capability name is invalid" do
      subject(:invoke) do
        CommandTower.config.registry.principal_capabilities.capability :"Bad-Name"
      end

      it "raises InvalidCapabilityNameError" do
        expect { invoke }.to raise_error(
          CommandTower::PrincipalCapabilities::InvalidCapabilityNameError
        )
      end
    end

    context "when the registry is finalized" do
      before { CommandTower.config.registry.principal_capabilities.finalize! }

      after { CommandTower.config.registry.principal_capabilities.reset_host_definitions! }

      it "rejects further registration" do
        expect {
          CommandTower.config.registry.principal_capabilities.capability :after_freeze
        }.to raise_error(CommandTower::PrincipalCapabilities::FrozenRegistryError)
      end
    end

    context "when seeded capabilities match composed entities", :with_rbac_setup do
      it "passes required entity validation" do
        expect {
          CommandTower.config.registry.principal_capabilities.validate_required_entities!(
            CommandTower::Authorization::Entity.entities
          )
        }.not_to raise_error
      end
    end

    context "when a required entity is missing from the RBAC graph" do
      before do
        CommandTower.config.registry.principal_capabilities.capability :broken_capability do |capability|
          capability.required_entity = :does_not_exist
        end
      end

      it "fails validation" do
        expect {
          CommandTower.config.registry.principal_capabilities.validate_required_entities!({})
        }.to raise_error(
          CommandTower::PrincipalCapabilities::MissingRequiredEntityError,
          /broken_capability/
        )
      end
    end
  end
end
