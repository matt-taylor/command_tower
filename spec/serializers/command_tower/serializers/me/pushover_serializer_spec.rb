# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Me::PushoverSerializer do
  it "returns unconfigured payload for nil" do
    expect(described_class.serialize(nil)).to eq(described_class.unconfigured)
  end

  context "with a safe view" do
    let(:view) do
      instance_double(
        "SafeView",
        id: 12,
        channel_key: "pushover",
        lifecycle_state: "active",
        verification_state: "unverified",
        masked_display_value: "****abcd",
        credentials_configured: true,
        verified_at: nil,
        created_at: Time.utc(2026, 1, 2, 3, 4, 5),
        updated_at: Time.utc(2026, 1, 2, 3, 4, 5)
      )
    end

    subject(:payload) { described_class.serialize(view) }

    it "serializes without secrets" do
      expect(payload).to include(
        configured: true,
        id: 12,
        channelKey: "pushover",
        lifecycleState: "active",
        verificationState: "unverified",
        maskedDisplayValue: "****abcd",
        credentialsConfigured: true
      )
      expect(payload[:actions]).to eq(
        canCreate: false,
        canVerify: true,
        canReplace: true,
        canRemove: true
      )
      expect(payload.to_json).not_to include("user_key")
      expect(payload.to_json).not_to include("application_token")
    end
  end
end
