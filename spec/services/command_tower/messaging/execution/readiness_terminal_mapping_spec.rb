# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::ReadinessTerminalMapping do
  subject(:mapper) { described_class }

  it "maps platform_disabled" do
    expect(mapper.error_code_for(%w[platform_disabled])).to eq("platform_disabled")
  end

  it "maps platform_unconfigured to adapter_unconfigured" do
    expect(mapper.error_code_for(%w[platform_unconfigured])).to eq("adapter_unconfigured")
  end

  it "maps identity_unverified" do
    expect(mapper.error_code_for(%w[identity_unverified])).to eq("recipient_unverified")
  end

  it "maps identity_missing" do
    expect(mapper.error_code_for(%w[identity_missing])).to eq("recipient_missing")
  end

  it "maps the first reason when multiple are present" do
    expect(
      mapper.error_code_for(%w[platform_unconfigured identity_unverified]),
    ).to eq("adapter_unconfigured")
  end

  it "defaults empty reasons to recipient_missing" do
    expect(mapper.error_code_for([])).to eq("recipient_missing")
  end
end
