# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Resolve, :messaging_preferences do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms] }

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      ),
    )
  end

  let(:resolve) do
    described_class.call(
      notification_type_key:,
      recipient_id: user.id,
      platform_enabled_channels:,
    )
  end

  context "with declaration defaults and no stored preference" do
    subject(:result) { resolve }

    it "uses declaration defaults when no stored preference exists" do
      expect(result.stored_override_present).to be(false)
      expect(result.permitted_channels).to contain_exactly("email", "sms")
      expect(result.inbox_permitted).to be(true)
      expect(result.effective_preference_state["channels"]).to include("email" => true)
    end
  end

  context "with a stored channel disable override" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "email" => false }, inbox: true),
      )
    end

    subject(:result) { resolve }

    it "applies a stored channel disable override" do
      expect(result.stored_override_present).to be(true)
      expect(result.permitted_channels).to eq(["sms"])
      expect(result.inbox_permitted).to be(true)
    end
  end

  context "with a partial override" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "sms" => false }),
      )
    end

    subject(:result) { resolve }

    it "preserves defaults for channels omitted from a partial override" do
      expect(result.permitted_channels).to eq(["email"])
      expect(result.effective_preference_state["channels"]).to include(
        "email" => true,
        "sms" => false,
      )
    end
  end

  context "when evaluating immutability" do
    subject(:result) { resolve }

    it "returns an immutable evaluation result" do
      expect(result).to be_frozen
      expect(result.permitted_channels).to be_frozen
      expect(result.effective_preference_state).to be_frozen
    end
  end

  context "with an unknown notification type" do
    subject(:invoke) do
      described_class.call(
        notification_type_key: "missing.type",
        recipient_id: user.id,
        platform_enabled_channels:,
      )
    end

    it "fails closed for an unknown notification type" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Preferences::UnknownTypeError)
    end
  end

  context "with a newly registered type and no existing rows" do
    before do
      CommandTower::Messaging::NotificationTypes.reset!
      register_and_seal_notification_types(
        build_notification_type_declaration(key: "brand.new.type"),
      )
    end

    subject(:result) do
      described_class.call(
        notification_type_key: "brand.new.type",
        recipient_id: user.id,
        platform_enabled_channels: %w[email sms],
      )
    end

    it "works for a newly registered type with no existing rows" do
      expect(result.stored_override_present).to be(false)
      expect(result.permitted_channels).to include("email")
    end
  end
end
