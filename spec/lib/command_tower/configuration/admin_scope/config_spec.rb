# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::AdminScope::Config do
  subject(:config) { described_class.new }

  let(:noop) { ->(*) {} }

  describe "#register" do
    it "stores a validated registration for a known tool" do
      registration = config.register(:users) do |entry|
        entry.options = noop
        entry.validate = noop
        entry.availability = noop
        entry.narrow_users = noop
        entry.narrow_audit = noop
        entry.affected_users_in_scope = noop
      end

      expect(config.fetch(:users)).to eq(registration)
    end

    it "rejects duplicate registrations" do
      config.register(:users) do |entry|
        entry.options = noop
        entry.validate = noop
        entry.availability = noop
        entry.narrow_users = noop
        entry.narrow_audit = noop
        entry.affected_users_in_scope = noop
      end

      expect do
        config.register(:users) do |entry|
          entry.options = noop
          entry.validate = noop
          entry.availability = noop
          entry.narrow_users = noop
          entry.narrow_audit = noop
          entry.affected_users_in_scope = noop
        end
      end.to raise_error(CommandTower::AdminScope::DuplicateRegistrationError)
    end

    it "rejects registrations after finalize" do
      config.finalize!

      expect do
        config.register(:users) do |entry|
          entry.options = noop
          entry.validate = noop
          entry.availability = noop
          entry.narrow_users = noop
          entry.narrow_audit = noop
          entry.affected_users_in_scope = noop
        end
      end.to raise_error(CommandTower::AdminScope::FrozenRegistryError)
    end
  end

  describe "#validate_scoped_tools!" do
    it "requires admin_scope registration for scope_required tools" do
      definition = CommandTower.config.registry.admin_workspace.fetch(:users)
      original_required = definition.scope_required
      definition.scope_required = true

      expect { config.validate_scoped_tools! }
        .to raise_error(CommandTower::AdminScope::MissingRegistrationError)
    ensure
      definition.scope_required = original_required
    end
  end
end
