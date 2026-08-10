# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Errors::ConfigurationError do
  it "is a StandardError" do
    expect(described_class.new("boom")).to be_a(StandardError)
  end

  it "carries the given message" do
    expect(described_class.new("client is required").message).to eq("client is required")
  end
end
