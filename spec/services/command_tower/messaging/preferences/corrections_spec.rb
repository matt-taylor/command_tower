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

  subject(:corrections) { described_class.build(submitted:, destinations:) }

  context "when a submitted boolean disagrees with effective" do
    let(:submitted) { { "email" => false } }

    it "builds a correction" do
      expect(corrections.length).to eq(1)
      expect(corrections.first.channel_key).to eq("email")
      expect(corrections.first.submitted).to be(false)
      expect(corrections.first.effective).to be(true)
      expect(corrections.first.reason_code).to eq("required")
    end
  end

  context "when destinations are omitted" do
    let(:submitted) { {} }

    it "does not build corrections" do
      expect(corrections).to eq([])
    end
  end

  context "when an unavailable destination is explicitly submitted" do
    let(:submitted) { { "sms" => true } }

    it "builds a correction" do
      expect(corrections.length).to eq(1)
      expect(corrections.first.channel_key).to eq("sms")
      expect(corrections.first.submitted).to be(true)
      expect(corrections.first.effective).to be(false)
    end
  end
end
