# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Messaging::Preferences::NotificationSerializer do
  let(:notification) do
    instance_double(
      "CatalogNotification",
      key: "booking_confirmation",
      label: "Booking Confirmation",
      description: nil,
      order: 10,
      configurable: true,
      mandatory: false,
      inbox_available: true,
      allowed_channels: %w[email sms],
      available_channels: %w[email],
      inbox_enabled: true,
      channels: { "email" => true, "sms" => false },
      stored_override_present: false,
      urgency: { default: "normal", allowed: %w[normal], selectable: false, effective: "normal" },
      sound: {
        default: "default",
        allowed: [{ id: "default", label: "System Default" }],
        selectable: false,
        effective: "default",
      },
      channel_catalog: [
        {
          key: "inbox",
          label: "Inbox",
          description: "In-app messages",
          order: 0,
          glyph_key: "inbox",
        },
        {
          key: "email",
          label: "Email",
          description: "Email to your account address",
          order: 1,
          glyph_key: "mail",
        },
        {
          key: "push",
          label: "Push",
          description: "Alerts on this device",
          order: 3,
          glyph_key: "bell",
        },
      ],
      destinations: {
        "email" => { state: "editable", effective: true, reason_code: nil, reason: nil },
        "sms" => { state: "unavailable", effective: false, reason_code: "unavailable", reason: "This destination is unavailable." },
      },
      corrections: nil,
    )
  end

  it "serializes the camelCase notification contract" do
    expect(described_class.serialize(notification)).to eq(
      key: "booking_confirmation",
      label: "Booking Confirmation",
      description: nil,
      order: 10,
      configurable: true,
      mandatory: false,
      inboxAvailable: true,
      allowedChannels: %w[email sms],
      availableChannels: %w[email],
      channelCatalog: [
        {
          key: "inbox",
          label: "Inbox",
          description: "In-app messages",
          order: 0,
          glyphKey: "inbox",
        },
        {
          key: "email",
          label: "Email",
          description: "Email to your account address",
          order: 1,
          glyphKey: "mail",
        },
        {
          key: "push",
          label: "Push",
          description: "Alerts on this device",
          order: 3,
          glyphKey: "bell",
        },
      ],
      destinations: {
        "email" => {
          state: "editable",
          effective: true,
          reasonCode: nil,
          reason: nil,
        },
        "sms" => {
          state: "unavailable",
          effective: false,
          reasonCode: "unavailable",
          reason: "This destination is unavailable.",
        },
      },
      urgency: { default: "normal", allowed: %w[normal], selectable: false, effective: "normal" },
      sound: {
        default: "default",
        allowed: [{ id: "default", label: "System Default" }],
        selectable: false,
        effective: "default",
      },
      preferences: {
        inboxEnabled: true,
        channels: { "email" => true, "sms" => false },
        storedOverridePresent: false,
      },
    )
  end
end
