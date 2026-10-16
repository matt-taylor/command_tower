# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Destinations, :messaging_preferences do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms push] }
  let(:declaration_overrides) { {} }
  let(:stored_preference) { nil }
  let(:available_channels) { %w[email sms push] }

  before do
    declaration = build_notification_type_declaration(key: notification_type_key, **declaration_overrides)
    register_and_seal_notification_types(declaration)

    next if stored_preference.nil?

    CommandTower::Messaging::Preferences.upsert_stored!(
      recipient_id: user.id,
      notification_type_key:,
      preference_state: stored_preference,
    )
  end

  subject(:destinations) do
    evaluation = CommandTower::Messaging::Preferences.resolve(
      notification_type_key:,
      recipient_id: user.id,
      platform_enabled_channels:,
    )

    described_class.call(
      declaration: CommandTower::Messaging::NotificationTypes.lookup(notification_type_key),
      evaluation:,
      available_channels:,
    )
  end

  context "when the channel is not in availableChannels" do
    let(:available_channels) { %w[email] }

    it "marks the channel unavailable" do
      expect(destinations["sms"]).to include(
        state: "unavailable",
        effective: false,
        reason_code: "unavailable",
      )
    end
  end

  context "when a forced_on lock is also unavailable" do
    let(:declaration_overrides) { { destination_locks: { "sms" => "forced_on" } } }
    let(:available_channels) { %w[email] }

    it "prefers unavailable" do
      expect(destinations["sms"][:state]).to eq("unavailable")
    end
  end

  context "when a mandatory channel is stored off" do
    let(:declaration_overrides) do
      {
        mandatory: true,
        default_channels: %w[email],
      }
    end
    let(:stored_preference) { { "channels" => { "email" => false } } }

    it "reports mandatory snap-back as forced_on with required" do
      expect(destinations["email"]).to include(
        state: "forced_on",
        effective: true,
        reason_code: "required",
      )
    end
  end

  context "when a destination is locked off" do
    let(:declaration_overrides) do
      {
        allowed_channels: %w[email sms push],
        destination_locks: { "push" => "forced_off" },
      }
    end

    it "reports a forced_off lock" do
      expect(destinations["push"]).to include(
        state: "forced_off",
        effective: false,
        reason_code: "locked_off",
      )
    end
  end
end
