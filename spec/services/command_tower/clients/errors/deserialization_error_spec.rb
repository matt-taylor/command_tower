# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Errors::DeserializationError do
  it "is an CommandTower::Errors::ApplicationError" do
    expect(described_class).to be < CommandTower::Errors::ApplicationError
  end

  describe "#code" do
    it { expect(described_class.new.code).to eq("deserialization_error") }
  end

  describe "#message" do
    it "defaults when no message is given" do
      expect(described_class.new.message).to eq("Failed to deserialize upstream response")
    end

    it "uses the given message" do
      expect(described_class.new(message: "bad field").message).to eq("bad field")
    end
  end

  describe "#log_level" do
    it { expect(described_class.new.log_level).to eq(:warn) }
  end
end
