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

  describe "presentation fields" do
    subject(:payload) do
      described_class.build(
        recipient_address: "1",
        title: "T",
        body: "B",
        sound: "chime.wav",
        urgency: "time_sensitive",
        thread_id: "league.1.period.2",
      )
    end

    it "carries the sound, urgency, and thread id" do
      expect(payload).to have_attributes(
        sound: "chime.wav",
        urgency: "time_sensitive",
        thread_id: "league.1.period.2",
        badge: nil,
      )
      expect(payload).to be_frozen
    end

    it "defaults to System Default, normal urgency, no thread, and no badge" do
      expect(described_class.build(recipient_address: "1", title: "T", body: "B"))
        .to have_attributes(sound: nil, urgency: "normal", thread_id: nil, badge: nil)
    end

    it "keeps a zero badge" do
      expect(described_class.build(recipient_address: "1", title: "T", body: "B", badge: 0).badge).to eq(0)
    end

    it "keeps a positive badge" do
      expect(described_class.build(recipient_address: "1", title: "T", body: "B", badge: 3).badge).to eq(3)
    end

    it "rejects a negative badge" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", badge: -1)
      }.to raise_error(ArgumentError, /badge/)
    end

    it "rejects a string badge" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", badge: "1")
      }.to raise_error(ArgumentError, /badge/)
    end

    it "rejects a float badge" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", badge: 1.5)
      }.to raise_error(ArgumentError, /badge/)
    end

    it "rejects an unknown urgency" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", urgency: "loud")
      }.to raise_error(ArgumentError, /urgency/)
    end

    it "rejects a blank sound" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", sound: " ")
      }.to raise_error(ArgumentError, /sound/)
    end

    it "rejects a blank thread id" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", thread_id: "")
      }.to raise_error(ArgumentError, /thread_id/)
    end

    it "rejects a thread id over 128 characters" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", thread_id: "a" * 129)
      }.to raise_error(ArgumentError, /128/)
    end

    it "rejects a non-string sound" do
      expect {
        described_class.build(recipient_address: "1", title: "T", body: "B", sound: 5)
      }.to raise_error(ArgumentError, /sound/)
    end
  end
end
