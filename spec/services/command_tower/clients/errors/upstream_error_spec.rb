# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Errors::UpstreamError do
  it "is an CommandTower::Errors::ApplicationError" do
    expect(described_class).to be < CommandTower::Errors::ApplicationError
  end

  describe "#code" do
    it { expect(described_class.new.code).to eq("upstream_error") }
  end

  describe "#message" do
    it "defaults when no message is given" do
      expect(described_class.new.message).to eq("Upstream request failed")
    end

    it "uses the given message" do
      expect(described_class.new(message: "boom").message).to eq("boom")
    end
  end

  describe "#log_level" do
    it { expect(described_class.new.log_level).to eq(:warn) }
  end
end
