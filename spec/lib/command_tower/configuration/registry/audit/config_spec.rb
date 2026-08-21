# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::Audit::Config do
  after { CommandTower::Current.reset }

  describe "#event" do
    context "when a CommandTower-owned event is seeded" do
      subject(:definition) { CommandTower.config.registry.audit.fetch(:role_assigned) }

      it "registers platform policy" do
        expect(definition.owner).to eq(:command_tower)
        expect(definition.enabled?).to eq(true)
        expect(definition.enablement_configurable?).to eq(false)
        expect(definition.user_history).to eq(true)
        expect(definition.allowed_changes).to eq([:role])
        expect(definition.sensitive_fields).to eq([])
        expect(definition.retention).to eq(:permanent)
        expect(definition.tags).to eq(%w[authorization identity rbac])
      end
    end

    context "when session_created is seeded" do
      subject(:definition) { CommandTower.config.registry.audit.fetch(:session_created) }

      it "is enabled and enablement-configurable" do
        expect(definition.enabled?).to eq(true)
        expect(definition.enablement_configurable?).to eq(true)
        expect(definition.user_history).to eq(false)
        expect(definition.retention).to eq(:ninety_days)
        expect(definition.tags).to eq(%w[authentication security session])
      end
    end

    context "when login_failed is seeded" do
      subject(:definition) { CommandTower.config.registry.audit.fetch(:login_failed) }

      it "is disabled by default and enablement-configurable" do
        expect(definition.enabled?).to eq(false)
        expect(definition.enablement_configurable?).to eq(true)
      end
    end

    context "when a host event is registered" do
      before do
        CommandTower.config.registry.audit.event :wager_placed do |event|
          event.enabled = true
          event.user_history = true
          event.sensitive_fields = []
          event.allowed_changes = %i[status]
          event.retention = :permanent
        end
      end

      subject(:definition) { CommandTower.config.registry.audit.fetch(:wager_placed) }

      it "lives in the same registry as CommandTower events" do
        expect(definition.owner).to eq(:host)
        expect(CommandTower.config.registry.audit.fetch(:user_registered).owner).to eq(:command_tower)
        expect(definition.allowed_changes).to eq([:status])
      end
    end

    context "when the same host event is registered twice" do
      before do
        CommandTower.config.registry.audit.event(:wager_placed)
      end

      subject(:invoke) { CommandTower.config.registry.audit.event(:wager_placed) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::DuplicateEventError, /already registered/)
      end
    end

    context "when a host redefines a CommandTower-owned event" do
      subject(:invoke) { CommandTower.config.registry.audit.event(:password_changed) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::HostOverrideError, /cannot redefine/)
      end
    end

    context "when the event name is invalid" do
      subject(:invoke) { CommandTower.config.registry.audit.event("UserEmail") }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidEventNameError, /invalid audit event name/)
      end
    end

    context "when sensitive fields are not in allowed changes" do
      subject(:invoke) do
        CommandTower.config.registry.audit.event :user_email_changed do |event|
          event.allowed_changes = %i[username]
          event.sensitive_fields = %i[email]
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidEventDefinitionError, /sensitive_fields/)
      end
    end

    context "when retention is invalid" do
      subject(:invoke) do
        CommandTower.config.registry.audit.event :custom_fact do |event|
          event.retention = :forever
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidEventDefinitionError, /invalid retention/)
      end
    end

    context "when the registry is finalized" do
      before { CommandTower.config.registry.audit.finalize! }

      subject(:invoke) { CommandTower.config.registry.audit.event(:after_freeze) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::FrozenRegistryError, /frozen/)
      end
    end
  end

  describe "#set_enabled!" do
    context "when the event is enablement-configurable" do
      before { CommandTower.config.registry.audit.set_enabled!(:login_failed, true) }

      subject(:definition) { CommandTower.config.registry.audit.fetch(:login_failed) }

      it "changes only enabled" do
        expect(definition.enabled?).to eq(true)
        expect(definition.enablement_configurable?).to eq(true)
        expect(definition.user_history).to eq(false)
        expect(definition.retention).to eq(:ninety_days)
      end
    end

    context "when the event is a mandatory CommandTower fact" do
      subject(:invoke) { CommandTower.config.registry.audit.set_enabled!(:password_changed, false) }

      it "raises" do
        expect { invoke }.to raise_error(
          CommandTower::Audit::EnablementNotConfigurableError,
          /not configurable/
        )
      end
    end

    context "when the name is unregistered" do
      subject(:invoke) { CommandTower.config.registry.audit.set_enabled!(:not_a_real_event, true) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::UnregisteredEventError)
      end
    end

    context "when the event is host-owned" do
      before do
        CommandTower.config.registry.audit.event :wager_placed do |event|
          event.enabled = true
        end
      end

      subject(:invoke) { CommandTower.config.registry.audit.set_enabled!(:wager_placed, false) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::HostOverrideError, /CommandTower-owned/)
      end
    end

    context "when the registry is finalized" do
      before { CommandTower.config.registry.audit.finalize! }

      subject(:invoke) { CommandTower.config.registry.audit.set_enabled!(:session_created, false) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::FrozenRegistryError, /frozen/)
      end
    end
  end

  describe "#fetch" do
    context "when the name is unregistered" do
      subject(:invoke) { CommandTower.config.registry.audit.fetch(:not_a_real_event) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::UnregisteredEventError, /not registered/)
      end
    end
  end
end
