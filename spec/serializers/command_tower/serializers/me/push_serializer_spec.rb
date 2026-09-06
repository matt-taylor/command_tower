# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Me::PushSerializer do
  let(:safe_view) do
    instance_double(
      CommandTower::Messaging::Endpoints::SafeView,
      id: 9,
      channel_key: "push",
      lifecycle_state: "active",
      verification_state: "verified",
      masked_display_value: "Device registered",
      verified_at: Time.utc(2026, 1, 2, 3, 4, 5),
      created_at: Time.utc(2026, 1, 1, 0, 0, 0),
      updated_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
  end

  describe ".serialize" do
    subject(:payload) { described_class.serialize(safe_view) }

    it "serializes camelCase fields without a raw token" do
      expect(payload).to include(
        id: 9,
        channelKey: "push",
        lifecycleState: "active",
        verificationState: "verified",
        maskedDisplayValue: "Device registered",
        actions: { canReplace: true, canRemove: true },
      )
      expect(payload.to_json).not_to match(/ExponentPushToken|ExpoPushToken/)
    end
  end

  describe ".serialize_collection" do
    subject(:payload) { described_class.serialize_collection([safe_view]) }

    it "wraps endpoints in a collection" do
      expect(payload[:endpoints].size).to eq(1)
      expect(payload[:endpoints].first[:id]).to eq(9)
    end
  end
end
