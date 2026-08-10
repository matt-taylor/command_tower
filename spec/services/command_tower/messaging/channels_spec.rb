# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Channels do
  describe ".keys" do
    it "returns all canonical channel keys in stable order" do
      expect(described_class.keys).to eq(%w[inbox email sms push pushover])
    end

    it "returns a frozen array" do
      expect(described_class.keys).to be_frozen
    end
  end

  describe ".external_keys" do
    it "excludes inbox" do
      expect(described_class.external_keys).to eq(%w[email sms push pushover])
    end

    it "returns a frozen array" do
      expect(described_class.external_keys).to be_frozen
    end
  end

  describe ".definitions" do
    it "returns frozen definitions for all channels" do
      expect(described_class.definitions).to all(be_frozen)
      expect(described_class.definitions.map(&:key)).to eq(described_class.keys)
    end

    it "freezes the definitions collection" do
      expect(described_class.definitions).to be_frozen
    end
  end

  describe ".known?" do
    it "returns true for catalog keys" do
      expect(described_class.known?("email")).to be(true)
      expect(described_class.known?(:sms)).to be(true)
    end

    it "returns false for unknown keys without downcasing" do
      expect(described_class.known?("Email")).to be(false)
      expect(described_class.known?("fax")).to be(false)
    end
  end

  describe ".fetch" do
    context "with a known key" do
      subject(:definition) { described_class.fetch("email") }

      it "returns the definition" do
        expect(definition).to have_attributes(
        key: "email",
        label: "Email",
        kind: :external,
        supports_endpoint_records: false,
        identity_backed: true,
        canonical_provider: "smtp",
        )
      end
    end

    it "returns nil for unknown keys" do
      expect(described_class.fetch("fax")).to be_nil
    end
  end

  describe ".fetch!" do
    it "returns the definition for a known key" do
      expect(described_class.fetch!("pushover").key).to eq("pushover")
    end

    it "raises UnknownChannelError for unknown keys" do
      expect {
        described_class.fetch!("fax")
      }.to raise_error(
        CommandTower::Messaging::Channels::UnknownChannelError,
        'unknown channel: "fax"',
      )
    end
  end

  describe "inbox definition metadata" do
    subject(:definition) { described_class.fetch!("inbox") }

    it "marks inbox as non-external with no canonical provider" do
      expect(definition).to have_attributes(
        key: "inbox",
        label: "Inbox",
        kind: :inbox,
        supports_endpoint_records: false,
        identity_backed: false,
        canonical_provider: nil,
      )
      expect(definition).not_to be_external
      expect(definition).to be_inbox
    end
  end

  describe "channel characteristic flags" do
    it "marks sms as identity-backed without endpoint records" do
      expect(described_class.fetch!("sms")).to have_attributes(
        identity_backed: true,
        supports_endpoint_records: false,
      )
    end

    it "marks push and pushover as endpoint-record channels only" do
      %w[push pushover].each do |key|
        expect(described_class.fetch!(key)).to have_attributes(
          identity_backed: false,
          supports_endpoint_records: true,
        )
      end
    end
  end
end
