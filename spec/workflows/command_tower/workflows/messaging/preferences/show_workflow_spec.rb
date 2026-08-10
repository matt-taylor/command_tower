# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::Preferences::ShowWorkflow, :messaging_preferences do
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

  subject(:result) { described_class.call(user:) }

  it "returns a serialized catalog payload" do
    expect(result).to be_success
    expect(result.http_status).to eq(:ok)
    expect(result.payload.keys).to contain_exactly(:categories)
  end
end
