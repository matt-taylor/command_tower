# frozen_string_literal: true

RSpec.describe CommandTower::Errors::ForbiddenError do
  subject(:error) { described_class.new }

  describe "#code" do
    it { expect(error.code).to eq("forbidden") }
  end

  describe "#message" do
    it { expect(error.message).to eq("Forbidden") }
  end

  describe "#log_level" do
    it { expect(error.log_level).to eq(:warn) }
  end
end
