# frozen_string_literal: true

RSpec.describe CommandTower::Errors::NotFoundError do
  subject(:error) { described_class.new }

  describe "#code" do
    it { expect(error.code).to eq("not_found") }
  end

  describe "#message" do
    it { expect(error.message).to eq("Not found") }
  end

  describe "#log_level" do
    it { expect(error.log_level).to eq(:info) }
  end
end
