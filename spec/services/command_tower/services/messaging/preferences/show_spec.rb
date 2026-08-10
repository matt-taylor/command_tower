# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Preferences::Show, :messaging_preferences do
  let(:user) { create(:user) }

  before do
    CommandTower.config.messaging.platform_enabled_channels = -> { %w[email] }
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "booking_confirmation",
        label: "Booking Confirmation",
        category_key: "reservations",
        category_label: "Reservations",
        category_order: 10,
        type_order: 10,
        allowed_channels: %w[email],
        default_channels: %w[email],
        settings_visible: true,
      ),
    )
  end

  after do
    CommandTower.config.messaging.platform_enabled_channels = -> { [] }
  end

  context "with the host-injected platform channels" do
    subject(:result) { described_class.call(user:) }

    it "returns a catalog for the recipient" do
      expect(result).to be_success
      expect(result.data[:catalog].categories.map(&:key)).to eq(%w[reservations])
    end
  end

  context "when platform channels are empty" do
    before { CommandTower.config.messaging.platform_enabled_channels = -> { [] } }

    subject(:result) { described_class.call(user:) }

    let(:booking) { result.data[:catalog].categories.first.notifications.first }

    it "uses the host-injected platform_enabled_channels callable" do
      expect(result).to be_success
      expect(booking.available_channels).to eq([])
    end
  end
end
