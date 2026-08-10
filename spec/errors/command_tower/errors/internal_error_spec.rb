# frozen_string_literal: true

RSpec.describe CommandTower::Errors::InternalError do
  subject(:error) { described_class.new }

  describe "#code" do
    it { expect(error.code).to eq("internal_error") }
  end

  describe "#message" do
    it { expect(error.message).to eq("Internal error") }
  end

  describe "#log_level" do
    it { expect(error.log_level).to eq(:error) }
  end
end
