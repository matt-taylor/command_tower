# frozen_string_literal: true

RSpec.describe CommandTower::Errors::UnauthorizedError do
  subject(:error) { described_class.new }

  describe "#code" do
    it { expect(error.code).to eq("unauthorized") }
  end

  describe "#message" do
    it { expect(error.message).to eq("Unauthorized") }
  end

  describe "#log_level" do
    it { expect(error.log_level).to eq(:warn) }
  end
end
