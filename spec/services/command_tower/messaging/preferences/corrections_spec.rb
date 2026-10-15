# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Corrections do
  let(:destinations) do
    {
      "email" => {
        state: "forced_on",
        effective: true,
        reason_code: "required",
        reason: CommandTower::Messaging::Preferences::Destinations::REASONS.fetch("required"),
      },
      "sms" => {
        state: "unavailable",
        effective: false,
        reason_code: "unavailable",
        reason: CommandTower::Messaging::Preferences::Destinations::REASONS.fetch("unavailable"),
      },
    }
  end

  it "builds a correction when a submitted boolean disagrees with effective" do
    corrections = described_class.build(
      submitted: { "email" => false },
      destinations:,
    )

    expect(corrections.length).to eq(1)
    expect(corrections.first.channel_key).to eq("email")
    expect(corrections.first.submitted).to be(false)
    expect(corrections.first.effective).to be(true)
    expect(corrections.first.reason_code).to eq("required")
  end

  it "does not build corrections for omitted destinations" do
    corrections = described_class.build(submitted: {}, destinations:)

    expect(corrections).to eq([])
  end

  it "builds a correction for an explicitly submitted unavailable destination" do
    corrections = described_class.build(
      submitted: { "sms" => true },
      destinations:,
    )

    expect(corrections.length).to eq(1)
    expect(corrections.first.channel_key).to eq("sms")
    expect(corrections.first.submitted).to be(true)
    expect(corrections.first.effective).to be(false)
  end
end
