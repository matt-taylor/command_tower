# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Preferences::Update, :messaging_preferences do
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
        user_configurable: true,
      ),
      build_notification_type_declaration(
        key: "hello_world",
        label: "Hello World",
        category_key: "development",
        category_label: "Development",
        category_order: 1000,
        type_order: 10,
        allowed_channels: [],
        default_channels: [],
        default_preference_state: { "channels" => {}, "inbox" => true },
        settings_visible: false,
        user_configurable: false,
      ),
    )
  end

  after do
    CommandTower.config.messaging.platform_enabled_channels = -> { [] }
  end

  context "when persisting a preference update" do
    subject(:result) do
      described_class.call(
        user:,
        notification_type_key: "booking_confirmation",
        preference_state: { "inbox" => false, "channels" => { "email" => false } },
      )
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "stores the preference change" do
      expect(result.data[:notification].inbox_enabled).to eq(false)
    end
  end

  context "with an unknown notification type" do
    subject(:result) do
      described_class.call(
        user:,
        notification_type_key: "missing",
        preference_state: {},
      )
    end

    it { expect(result).to be_failure }
    it { expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError) }
  end

  context "with a settings-hidden notification type" do
    subject(:result) do
      described_class.call(
        user:,
        notification_type_key: "hello_world",
        preference_state: {},
      )
    end

    it { expect(result).to be_failure }
    it { expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError) }
  end
end
