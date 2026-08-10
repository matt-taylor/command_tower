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
      preferences: {
        inboxEnabled: true,
        channels: { "email" => true, "sms" => false },
        storedOverridePresent: false,
      },
    )
  end
end
