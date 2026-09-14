# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::InboxPresentations::Config do
  subject(:registry) { CommandTower.config.registry.inbox_presentations }

  describe "#presentation" do
    context "when no presentations are registered" do
      it "seeds no CommandTower-owned presentations" do
        expect(registry.definitions).to be_empty
      end
    end

    context "when a host presentation is registered" do
      before do
        registry.presentation "pickem.make_picks" do |presentation|
          presentation.composer_class = "Services::Competitive::Presentations::MakePicks"
          presentation.output_keys = [:picks]
        end
      end

      subject(:definition) { registry.fetch("pickem.make_picks") }

      it "stores the composer_class, output_keys, and defaults owner to :host" do
        expect(definition.owner).to eq(:host)
        expect(definition.composer_class).to eq("Services::Competitive::Presentations::MakePicks")
        expect(definition.output_keys).to eq([:picks])
      end
    end

    context "when the same key is registered twice" do
      before do
        registry.presentation "pickem.make_picks" do |presentation|
          presentation.composer_class = "Services::Competitive::Presentations::MakePicks"
          presentation.output_keys = [:picks]
        end
      end

      subject(:invoke) do
        registry.presentation "pickem.make_picks" do |presentation|
          presentation.composer_class = "Services::Competitive::Presentations::MakePicks"
          presentation.output_keys = [:picks]
        end
      end

      it "raises DuplicateCapabilityError" do
        expect { invoke }.to raise_error(
          CommandTower::InboxPresentations::DuplicateCapabilityError,
          /pickem\.make_picks/,
        )
      end
    end

    context "when the presentation key is invalid" do
      subject(:invoke) { registry.presentation "Bad Key!" }

      it "raises InvalidKeyError" do
        expect { invoke }.to raise_error(CommandTower::InboxPresentations::InvalidKeyError)
      end
    end

    context "when composer_class is not set" do
      subject(:invoke) { registry.presentation "pickem.missing_composer" }

      it "raises InvalidPresentationDefinitionError" do
        expect { invoke }.to raise_error(
          CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
          /composer_class/,
        )
      end
    end

    context "when output_keys is not set" do
      subject(:invoke) do
        registry.presentation("pickem.missing_output_keys") { |p| p.composer_class = "Services::Competitive::Presentations::MakePicks" }
      end

      it "raises InvalidPresentationDefinitionError" do
        expect { invoke }.to raise_error(
          CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
          /output_keys/,
        )
      end
    end

    context "when the registry is finalized" do
      before { registry.finalize! }

      it "rejects further registration" do
        expect {
          registry.presentation("pickem.after_freeze") { |p| p.composer_class = "SomeClass" }
        }.to raise_error(CommandTower::InboxPresentations::FrozenRegistryError)
      end
    end
  end

  describe "#fetch" do
    context "when the key is unregistered" do
      subject(:invoke) { registry.fetch("pickem.unregistered") }

      it "raises UnregisteredCapabilityError" do
        expect { invoke }.to raise_error(CommandTower::InboxPresentations::UnregisteredCapabilityError)
      end
    end
  end

  describe "#registered?" do
    context "when the key is registered" do
      before do
        registry.presentation("pickem.make_picks") do |p|
          p.composer_class = "Services::Competitive::Presentations::MakePicks"
          p.output_keys = [:picks]
        end
      end

      it "returns true" do
        expect(registry.registered?("pickem.make_picks")).to be(true)
      end
    end

    context "when the key is unregistered" do
      it "returns false" do
        expect(registry.registered?("pickem.unregistered")).to be(false)
      end
    end

    context "when the key is malformed" do
      it "returns false rather than raising" do
        expect(registry.registered?("Bad Key!")).to be(false)
      end
    end
  end

  describe "#reset_host_definitions!" do
    before do
      registry.presentation("pickem.make_picks") do |p|
        p.composer_class = "Services::Competitive::Presentations::MakePicks"
        p.output_keys = [:picks]
      end
      registry.finalize!
    end

    it "removes host-owned definitions and unfreezes the registry for further registration" do
      registry.reset_host_definitions!

      expect(registry.registered?("pickem.make_picks")).to be(false)
      expect(registry.finalized?).to be(false)
    end
  end
end
