# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::RenderedPushPayload do
  describe ".build" do
    subject(:payload) do
      described_class.build(
        recipient_address: "42",
        title: "Hello",
        body: "World",
        deep_link: "pickem://x",
      )
    end

    it "builds a frozen push payload with optional deep_link" do
      expect(payload).to be_frozen
      expect(payload.recipient_address).to eq("42")
      expect(payload.title).to eq("Hello")
      expect(payload.body).to eq("World")
      expect(payload.deep_link).to eq("pickem://x")
    end
  end

  context "when deep_link is omitted" do
    subject(:payload) do
      described_class.build(recipient_address: "1", title: "T", body: "B")
    end

    it "allows a nil deep_link" do
      expect(payload.deep_link).to be_nil
    end
  end

  context "when body is blank" do
    subject(:invoke) do
      described_class.build(recipient_address: "1", title: "T", body: "")
    end

    it "rejects blank body" do
      expect { invoke }.to raise_error(ArgumentError)
    end
  end

  context "when deep_link is blank" do
    subject(:invoke) do
      described_class.build(recipient_address: "1", title: "T", body: "B", deep_link: "  ")
    end

    it "rejects blank deep_link when provided" do
      expect { invoke }.to raise_error(ArgumentError)
    end
  end

  context "when recipient_address is an ActiveRecord" do
    subject(:invoke) do
      described_class.build(recipient_address: User.new, title: "T", body: "B")
    end

    it "rejects ActiveRecord values" do
      expect { invoke }.to raise_error(ArgumentError, /ActiveRecord/)
    end
  end
end
