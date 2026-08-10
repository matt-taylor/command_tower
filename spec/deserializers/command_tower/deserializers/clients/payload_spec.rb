# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Clients::Payload do
  describe ".fetch" do
    subject(:fetched) { described_class.fetch(payload, key) }

    let(:key) { "name" }

    context "when the key is present with a value" do
      let(:payload) { { "name" => "Studio" } }

      it "returns the value" do
        expect(fetched).to eq("Studio")
      end
    end

    context "when the key is present with explicit nil" do
      let(:payload) { { "name" => nil } }

      it "returns nil, not Missing" do
        expect(fetched).to be_nil
        expect(fetched).not_to equal(CommandTower::Deserializers::Clients::Missing)
      end
    end

    context "when the key is absent" do
      let(:payload) { {} }

      it "returns the Missing sentinel" do
        expect(fetched).to equal(CommandTower::Deserializers::Clients::Missing)
      end
    end

    context "when payload is not a Hash" do
      subject(:invoke) { described_class.fetch("x", "name") }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /Hash/)
      end
    end
  end
end
