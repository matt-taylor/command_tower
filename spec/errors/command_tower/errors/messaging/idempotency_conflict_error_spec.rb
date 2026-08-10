# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Messaging::IdempotencyConflictError do
  subject(:error) { described_class.new }

  describe "#code" do
    it "returns the stable messaging idempotency conflict code" do
      expect(error.code).to eq("messaging_idempotency_conflict")
    end
  end

  describe "#message" do
    it "returns the produce-path conflict message" do
      expect(error.message).to eq("Messaging accept conflicts with an existing host event")
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
