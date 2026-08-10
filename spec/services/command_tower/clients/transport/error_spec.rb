# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Transport::Error do
  it "is a StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end

  it "carries the given message" do
    expect(described_class.new("timed out").message).to eq("timed out")
  end

  describe "with an optional cause" do
    let(:original) { StandardError.new("boom") }
    subject(:error) { described_class.new("wrapped", cause: original) }

    it "carries the cause" do
      expect(error.cause).to equal(original)
    end
  end
end
