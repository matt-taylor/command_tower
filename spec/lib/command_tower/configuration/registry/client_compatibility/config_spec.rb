# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::ClientCompatibility::Config do
  subject(:registry) { described_class.new }

  let(:known_entities) { { "session" => true, "me" => true } }

  describe "#opted_in?" do
    it "is false for a completely untouched registry" do
      expect(registry.opted_in?).to be(false)
    end

    it "is true once mode is set to enforce" do
      registry.mode = :enforce

      expect(registry.opted_in?).to be(true)
    end

    it "is true once a platform is configured" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }

      expect(registry.opted_in?).to be(true)
    end
  end

  describe "#platform" do
    it "registers a canonical platform with a strict minimum" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }

      expect(registry.platform_policy(:web).minimum).to eq("1.0.0")
    end

    it "rejects an unknown platform name" do
      expect { registry.platform(:desktop) { |p| p.minimum = "1.0.0" } }
        .to raise_error(CommandTower::ClientCompatibility::InvalidPlatformError)
    end

    it "rejects a malformed configured minimum" do
      expect { registry.platform(:web) { |p| p.minimum = "1.0" } }
        .to raise_error(CommandTower::ClientCompatibility::InvalidVersionError)
    end

    it "rejects a recommended version lower than the minimum" do
      expect do
        registry.platform(:web) do |p|
          p.minimum = "2.0.0"
          p.recommended = "1.0.0"
        end
      end.to raise_error(CommandTower::ClientCompatibility::ConflictingRequirementError)
    end

    it "rejects an update_url on web" do
      expect do
        registry.platform(:web) do |p|
          p.minimum = "1.0.0"
          p.update_url = "https://example.com"
        end
      end.to raise_error(CommandTower::ClientCompatibility::InvalidPlatformError)
    end
  end

  describe "#client_contract and #bind" do
    it "allows binding a registered contract" do
      registry.client_contract("account.audit.v2")
      registry.bind("account.audit.v2") { |b| b.ios = "3.0.0" }

      expect(registry.binding_for("account.audit.v2").ios).to eq("3.0.0")
    end

    it "raises when binding an unknown contract" do
      expect { registry.bind("account.unknown") { |b| b.ios = "3.0.0" } }
        .to raise_error(CommandTower::ClientCompatibility::UnknownClientContractError)
    end

    it "raises when a host redefines a CommandTower-owned contract" do
      registry.client_contract("owned.contract", owner: :command_tower)

      expect { registry.client_contract("owned.contract") }
        .to raise_error(CommandTower::ClientCompatibility::HostOverrideError)
    end

    it "raises on a duplicate host contract" do
      registry.client_contract("dup.contract")

      expect { registry.client_contract("dup.contract") }
        .to raise_error(CommandTower::ClientCompatibility::DuplicateContractError)
    end

    it "raises on a duplicate binding for the same contract" do
      registry.client_contract("dup.bind")
      registry.bind("dup.bind") { |b| b.ios = "3.0.0" }

      expect { registry.bind("dup.bind") { |b| b.ios = "3.0.1" } }
        .to raise_error(CommandTower::ClientCompatibility::DuplicateBindingError)
    end
  end

  describe "#entity" do
    it "accepts a client_contract reference" do
      registry.client_contract("account.audit.v2")
      registry.entity("session") { |e| e.client_contract = "account.audit.v2" }

      expect(registry.entity_requirement("session").client_contract).to eq("account.audit.v2")
    end

    it "accepts a direct per-platform minimum" do
      registry.entity("session") { |e| e.minimum.ios = "2.0.0" }

      expect(registry.entity_requirement("session").minimum.ios).to eq("2.0.0")
    end

    it "rejects both a client_contract and a direct minimum on the same requirement" do
      registry.client_contract("account.audit.v2")

      expect do
        registry.entity("session") do |e|
          e.client_contract = "account.audit.v2"
          e.minimum.ios = "2.0.0"
        end
      end.to raise_error(CommandTower::ClientCompatibility::ConflictingRequirementError)
    end

    it "requires a CommandTower-owned entity requirement to declare a client_contract" do
      expect do
        registry.entity("session", owner: :command_tower) { |e| e.minimum.ios = "2.0.0" }
      end.to raise_error(CommandTower::ClientCompatibility::ConflictingRequirementError)
    end

    it "raises when a host redefines a CommandTower-owned entity requirement" do
      registry.client_contract("owned.contract", owner: :command_tower)
      registry.entity("session", owner: :command_tower) { |e| e.client_contract = "owned.contract" }

      expect { registry.entity("session") { |e| e.minimum.ios = "2.0.0" } }
        .to raise_error(CommandTower::ClientCompatibility::HostOverrideError)
    end
  end

  describe "#validate!" do
    it "is a no-op for a completely untouched registry" do
      expect { registry.validate!(known_entities) }.not_to raise_error
    end

    it "does not fail solely because android is unconfigured" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }

      expect { registry.validate!(known_entities) }.not_to raise_error
    end

    it "passes with an empty catalog and no binds" do
      registry.mode = :enforce
      registry.platform(:web) { |p| p.minimum = "1.0.0" }

      expect { registry.validate!(known_entities) }.not_to raise_error
    end

    it "fails when opted in with zero configured platforms" do
      registry.mode = :enforce

      expect { registry.validate!(known_entities) }
        .to raise_error(CommandTower::ClientCompatibility::NoConfiguredPlatformsError)
    end

    it "fails on an entity requirement referencing an unknown RBAC entity" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.entity("not_a_real_entity") { |e| e.minimum.web = "1.0.0" }

      expect { registry.validate!(known_entities) }
        .to raise_error(CommandTower::ClientCompatibility::UnknownEntityError)
    end

    it "fails on an entity requirement referencing an unbound client contract" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.client_contract("account.audit.v2")
      registry.entity("session") { |e| e.client_contract = "account.audit.v2" }

      expect { registry.validate!(known_entities) }
        .to raise_error(CommandTower::ClientCompatibility::UnboundClientContractError)
    end

    it "passes when the referenced contract is bound for every configured platform" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.client_contract("account.audit.v2")
      registry.bind("account.audit.v2") { |b| b.web = "1.0.0" }
      registry.entity("session") { |e| e.client_contract = "account.audit.v2" }

      expect { registry.validate!(known_entities) }.not_to raise_error
    end

    it "fails when a direct entity minimum is lower than the platform-global minimum" do
      registry.platform(:web) { |p| p.minimum = "2.0.0" }
      registry.entity("session") { |e| e.minimum.web = "1.0.0" }

      expect { registry.validate!(known_entities) }
        .to raise_error(CommandTower::ClientCompatibility::ConflictingRequirementError)
    end
  end

  describe "#apply_env_overlay!" do
    it "raises the mode from ENV" do
      registry.apply_env_overlay!(env: { "COMMAND_TOWER_CLIENT_COMPATIBILITY_MODE" => "enforce" })

      expect(registry.mode).to eq(:enforce)
    end

    it "raises an already-configured platform's minimum" do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }

      registry.apply_env_overlay!(env: { "COMMAND_TOWER_CLIENT_COMPATIBILITY_MINIMUM_WEB" => "1.5.0" })

      expect(registry.platform_policy(:web).minimum).to eq("1.5.0")
    end

    it "never lowers an already-configured platform's minimum" do
      registry.platform(:web) { |p| p.minimum = "2.0.0" }

      registry.apply_env_overlay!(env: { "COMMAND_TOWER_CLIENT_COMPATIBILITY_MINIMUM_WEB" => "1.0.0" })

      expect(registry.platform_policy(:web).minimum).to eq("2.0.0")
    end

    it "does not configure a platform the host never enabled" do
      registry.apply_env_overlay!(env: { "COMMAND_TOWER_CLIENT_COMPATIBILITY_MINIMUM_IOS" => "1.0.0" })

      expect(registry.platform_policy(:ios)).to be_nil
    end
  end

  describe "#reset_host_definitions!" do
    it "clears host-owned platforms, entities, bindings, and mode" do
      registry.mode = :enforce
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.entity("session") { |e| e.minimum.web = "1.0.0" }

      registry.reset_host_definitions!

      expect(registry.mode).to eq(:observe)
      expect(registry.configured_platforms).to be_empty
      expect(registry.entity_requirement("session")).to be_nil
    end
  end
end
