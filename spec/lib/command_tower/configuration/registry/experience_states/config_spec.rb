# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::ExperienceStates::Config, :aggregate_failures do
  subject(:registry) { described_class.new }

  describe "defaults" do
    it "caps rows per user at 250" do
      expect(registry.max_rows_per_user).to eq(250)
    end

    it "rate limits complete to 30 per 60 seconds" do
      expect(registry.complete_rate).to eq(limit: 30, window: 60)
    end

    it "is hooked into the registry config" do
      expect(CommandTower.config.registry.experience_states).to be_a(described_class)
    end

    it "keeps the dummy host key registered for existing specs" do
      expect(CommandTower.config.registry.experience_states.registered?("welcome")).to be(true)
    end
  end

  describe "#register" do
    it "stores the key with its scope types and host owner" do
      registry.register("welcome", scope_types: %w[account])

      expect(registry.fetch("welcome").scope_types).to eq(%w[account])
      expect(registry.fetch("welcome").owner).to eq(:host)
      expect(registry.registered?("welcome")).to be(true)
    end

    it "accepts keys with colons and dots" do
      expect { registry.register("checklist:dfm.get-set-up:hidden", scope_types: %w[account]) }.not_to raise_error
    end

    it "raises on a duplicate key" do
      registry.register("welcome", scope_types: %w[account])

      expect { registry.register("welcome", scope_types: %w[account]) }
        .to raise_error(CommandTower::ExperienceStates::DuplicateKeyError)
    end

    it "raises on a blank key" do
      expect { registry.register(" ", scope_types: %w[account]) }
        .to raise_error(CommandTower::ExperienceStates::InvalidKeyError)
    end

    it "raises on a key over 128 characters" do
      expect { registry.register("a" * 129, scope_types: %w[account]) }
        .to raise_error(CommandTower::ExperienceStates::InvalidKeyError)
    end

    it "accepts a key of exactly 128 characters" do
      expect { registry.register("a" * 128, scope_types: %w[account]) }.not_to raise_error
    end

    it "raises when no scope type is given" do
      expect { registry.register("welcome", scope_types: []) }
        .to raise_error(CommandTower::ExperienceStates::InvalidDefinitionError)
    end
  end

  describe "#fetch" do
    it "raises without echoing the key for an unregistered key" do
      expect { registry.fetch("secret-key") }
        .to raise_error(CommandTower::ExperienceStates::UnregisteredKeyError) { |error|
          expect(error.message).not_to include("secret-key")
        }
    end
  end

  describe "#finalize!" do
    before do
      registry.register("welcome", scope_types: %w[account])
      registry.finalize!
    end

    it "freezes the registry and rejects further registration" do
      expect(registry).to be_finalized
      expect(registry.definitions).to be_frozen
      expect { registry.register("other", scope_types: %w[account]) }
        .to raise_error(CommandTower::ExperienceStates::FrozenRegistryError)
    end
  end

  describe "#reset_host_definitions!" do
    before do
      registry.register("welcome", scope_types: %w[account])
      registry.register("fixture_key", scope_types: %w[account], owner: :fixture)
      registry.finalize!
      registry.reset_host_definitions!
    end

    it "removes host keys, keeps others, and unfreezes" do
      expect(registry.registered?("welcome")).to be(false)
      expect(registry.registered?("fixture_key")).to be(true)
      expect(registry).not_to be_finalized
      expect { registry.register("again", scope_types: %w[account]) }.not_to raise_error
    end
  end

  describe "#validate_registered!" do
    let(:logger) { instance_double(ActiveSupport::Logger, error: nil) }

    before { allow(Rails).to receive(:logger).and_return(logger) }

    it "raises in the test environment when host_key is set and the registry is empty" do
      expect { registry.validate_registered!(host_key: "host", env: "test") }
        .to raise_error(CommandTower::ExperienceStates::EmptyRegistryError)
    end

    %w[development production].each do |env|
      it "logs an error in #{env} instead of raising" do
        expect { registry.validate_registered!(host_key: "host", env:) }.not_to raise_error
        expect(logger).to have_received(:error).with(/registry is empty/)
      end
    end

    it "does nothing when host_key is blank" do
      expect { registry.validate_registered!(host_key: "", env: "test") }.not_to raise_error
      expect(logger).not_to have_received(:error)
    end

    it "does nothing when keys are registered" do
      registry.register("welcome", scope_types: %w[account])

      expect { registry.validate_registered!(host_key: "host", env: "test") }.not_to raise_error
    end
  end
end
