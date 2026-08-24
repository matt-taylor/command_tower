# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::AdminScope::Config do
  subject(:config) { described_class.new }

  let(:noop) { ->(*) {} }
  let(:register_users!) do
    lambda do
      config.register(:users) do |entry|
        entry.options = noop
        entry.validate = noop
        entry.availability = noop
        entry.narrow_users = noop
        entry.narrow_audit = noop
        entry.affected_users_in_scope = noop
      end
    end
  end

  describe "#register" do
    context "when registering a known tool" do
      subject(:registration) { register_users!.call }

      it "stores a validated registration" do
        expect(registration).to eq(config.fetch(:users))
      end
    end

    context "when registering a duplicate" do
      before { register_users!.call }

      subject(:invoke) { register_users!.call }

      it "rejects duplicate registrations" do
        expect { invoke }.to raise_error(CommandTower::AdminScope::DuplicateRegistrationError)
      end
    end

    context "when the registry is finalized" do
      before { config.finalize! }

      subject(:invoke) { register_users!.call }

      it "rejects registrations after finalize" do
        expect { invoke }.to raise_error(CommandTower::AdminScope::FrozenRegistryError)
      end
    end

    context "when users omits resource-narrowing hooks" do
      subject(:invoke) do
        config.register(:users) do |entry|
          entry.options = noop
          entry.validate = noop
          entry.availability = noop
        end
      end

      it "rejects incomplete users registrations" do
        expect { invoke }.to raise_error(
          CommandTower::AdminScope::InvalidToolRegistrationError,
          /narrow_users/
        )
      end
    end

    context "when a host product tool registers base hooks only" do
      before do
        CommandTower.config.registry.admin_workspace.tool :host_scoped_product do |tool|
          tool.label = "Host Scoped Product"
          tool.description = "Test host scoped product tool."
          tool.route = "/admin/host-scoped-product"
          tool.group = :product
          tool.sort_order = 900
          tool.required_entity = :admin_users
          tool.scope_required = true
          tool.scope_parameter = "resource_slug"
          tool.scope_label = "Resource"
        end
      end

      after { CommandTower.config.registry.admin_workspace.reset_host_definitions! }

      subject(:registration) do
        config.register(:host_scoped_product) do |entry|
          entry.options = noop
          entry.validate = noop
          entry.availability = noop
        end
      end

      it "accepts product tools without Users/Audit narrowing hooks" do
        expect(registration.options).to eq(noop)
        expect(registration.narrow_users).to be_nil
      end
    end

    context "when a product tool sets only one narrowing hook" do
      before do
        CommandTower.config.registry.admin_workspace.tool :host_partial_narrow do |tool|
          tool.label = "Host Partial Narrow"
          tool.description = "Test partial narrowing requirement."
          tool.route = "/admin/host-partial-narrow"
          tool.group = :product
          tool.sort_order = 901
          tool.required_entity = :admin_users
          tool.scope_required = true
          tool.scope_parameter = "resource_slug"
          tool.scope_label = "Resource"
        end
      end

      after { CommandTower.config.registry.admin_workspace.reset_host_definitions! }

      subject(:invoke) do
        config.register(:host_partial_narrow) do |entry|
          entry.options = noop
          entry.validate = noop
          entry.availability = noop
          entry.narrow_users = noop
        end
      end

      it "requires the full narrowing set when any narrowing hook is present" do
        expect { invoke }.to raise_error(
          CommandTower::AdminScope::InvalidToolRegistrationError,
          /narrow_audit/
        )
      end
    end
  end

  describe "#validate_scoped_tools!" do
    context "when a platform tool requires scope without registration" do
      before do
        CommandTower.config.registry.admin_workspace.configure_tool(:users) do |tool|
          tool.scope_required = true
          tool.scope_parameter = "partition"
          tool.scope_label = "Partition"
        end
      end

      after { CommandTower.config.registry.admin_workspace.reset_platform_tool_scope_config! }

      subject(:invoke) { config.validate_scoped_tools! }

      it "requires admin_scope registration for scope_required tools" do
        expect { invoke }.to raise_error(CommandTower::AdminScope::MissingRegistrationError)
      end
    end
  end
end
