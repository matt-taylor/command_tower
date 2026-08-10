# frozen_string_literal: true

RSpec.describe CommandTower::Errors::ValidationError do
  subject(:error) { described_class.new(details: { failures: [] }) }

  describe "#code" do
    it { expect(error.code).to eq("validation_failed") }
  end

  describe "#message" do
    it { expect(error.message).to eq("Validation failed") }
  end
end
