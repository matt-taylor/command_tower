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
        expect(config.fetch(:users)).to eq(registration)
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
