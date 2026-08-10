# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Errors::DiscoveryError do
  it "is a ConfigurationError" do
    expect(described_class).to be < CommandTower::Clients::Errors::ConfigurationError
  end

  it "carries the given message" do
    expect(described_class.new("missing provider").message).to eq("missing provider")
  end
end
