# frozen_string_literal: true

RSpec.describe CommandTower::Errors::ApplicationError do
  subject(:error) { described_class.new(details: { a: 1 }, cause: cause) }

  let(:cause) { StandardError.new("root") }

  describe "#details" do
    it { expect(error.details).to eq(a: 1) }
  end

  describe "#cause" do
    it { expect(error.cause).to eq(cause) }
  end

  describe "#retryable?" do
    it { expect(error.retryable?).to be(false) }
  end

  describe "#log_level" do
    it { expect(error.log_level).to eq(:info) }
  end

  describe "#code" do
    it "raises NotImplementedError" do
      expect { error.code }.to raise_error(NotImplementedError)
    end
  end
end
