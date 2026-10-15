# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Destinations, :messaging_preferences do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms push] }

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms push],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        settings_visible: true,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true, "push" => true },
          "inbox" => true,
        },
      ),
    )
  end

  def resolve(declaration_overrides: {}, stored: nil, available: %w[email sms push])
    declaration = build_notification_type_declaration(key: notification_type_key, **declaration_overrides)
    register_and_seal_notification_types(declaration)

    if stored
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: stored,
      )
    end

    evaluation = CommandTower::Messaging::Preferences.resolve(
      notification_type_key:,
      recipient_id: user.id,
      platform_enabled_channels:,
    )

    described_class.call(
      declaration: CommandTower::Messaging::NotificationTypes.lookup(notification_type_key),
      evaluation:,
      available_channels: available,
    )
  end

  it "marks a channel unavailable when it is not in availableChannels" do
    destinations = resolve(available: %w[email])

    expect(destinations["sms"]).to include(
      state: "unavailable",
      effective: false,
      reason_code: "unavailable",
    )
  end

  it "prefers unavailable over a forced_on lock" do
    destinations = resolve(
      declaration_overrides: { destination_locks: { "sms" => "forced_on" } },
      available: %w[email],
    )

    expect(destinations["sms"][:state]).to eq("unavailable")
  end

  it "reports mandatory snap-back as forced_on with required" do
    destinations = resolve(
      declaration_overrides: {
        mandatory: true,
        default_channels: %w[email],
      },
      stored: { "channels" => { "email" => false } },
    )

    expect(destinations["email"]).to include(
      state: "forced_on",
      effective: true,
      reason_code: "required",
    )
  end

  it "reports a forced_off lock" do
    destinations = resolve(
      declaration_overrides: {
        allowed_channels: %w[email sms push],
        destination_locks: { "push" => "forced_off" },
      },
    )

    expect(destinations["push"]).to include(
      state: "forced_off",
      effective: false,
      reason_code: "locked_off",
    )
  end
end
