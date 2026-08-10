# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Messaging::AcceptRejectedError do
  subject(:error) { described_class.new }

  describe "#code" do
    it "returns the stable messaging accept rejected code" do
      expect(error.code).to eq("messaging_accept_rejected")
    end
  end

  describe "#message" do
    it "returns the produce-path rejection message" do
      expect(error.message).to eq("Messaging accept was rejected")
    end
  end

  describe "#log_level" do
    it "logs at warn" do
      expect(error.log_level).to eq(:warn)
    end
  end

  describe "#retryable?" do
    it "is not retryable" do
      expect(error.retryable?).to be(false)
    end
  end
end
