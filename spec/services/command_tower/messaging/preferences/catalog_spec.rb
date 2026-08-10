# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Catalog, :messaging_preferences do
  let(:user) { create(:user) }
  let(:platform_enabled_channels) { %w[email] }

  let(:catalog) do
    described_class.call(
      recipient_id: user.id,
      platform_enabled_channels:,
    )
  end

  describe "ordering and visibility" do
    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: "promo.announcement",
          label: "Promo",
          category_key: "marketing",
          category_label: "Marketing",
          category_order: 40,
          type_order: 10,
          allowed_channels: %w[email],
          default_channels: %w[email],
          settings_visible: true,
        ),
        build_notification_type_declaration(
          key: "booking.confirmation",
          label: "Booking Confirmation",
          category_key: "reservations",
          category_label: "Reservations",
          category_order: 10,
          type_order: 20,
          allowed_channels: %w[email],
          default_channels: %w[email],
          settings_visible: true,
        ),
        build_notification_type_declaration(
          key: "booking.cancellation",
          label: "Booking Cancellation",
          category_key: "reservations",
          category_label: "Reservations",
          category_order: 10,
          type_order: 10,
          allowed_channels: %w[email],
          default_channels: %w[email],
          settings_visible: true,
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
          user_configurable: false,
          settings_visible: false,
          default_preference_state: {
            "channels" => {},
            "inbox" => true,
          },
        ),
      )
    end

    subject(:result) { catalog }

    it "preserves registry category and notification ordering" do
      expect(result.categories.map(&:key)).to eq(%w[reservations marketing])
      expect(result.categories.first.notifications.map(&:key)).to eq(
        %w[booking.cancellation booking.confirmation],
      )
    end

    it "excludes settings_visible false notifications and drops empty categories" do
      expect(result.categories.flat_map { |category| category.notifications.map(&:key) }).not_to include("hello_world")
      expect(result.categories.map(&:key)).not_to include("development")
    end

    it "sets category description to nil" do
      expect(result.categories.first.description).to be_nil
    end
  end

  describe "effective preference mapping" do
    let(:notification_type_key) { "booking.success" }

    let(:notification) do
      catalog.categories
        .flat_map(&:notifications)
        .find { |entry| entry.key == notification_type_key }
    end

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: "booking.success",
          allowed_channels: %w[email sms],
          default_channels: %w[email],
          inbox_available: true,
          user_configurable: true,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true, "sms" => true },
            "inbox" => true,
          },
          settings_visible: true,
        ),
        build_notification_type_declaration(
          key: "password.changed",
          label: "Password Changed",
          category_key: "account",
          category_label: "Account",
          category_order: 30,
          type_order: 10,
          allowed_channels: %w[email],
          default_channels: %w[email],
          user_configurable: false,
          mandatory: true,
          settings_visible: true,
          default_preference_state: {
            "channels" => { "email" => true },
            "inbox" => true,
          },
        ),
      )
    end

    it "maps declaration defaults when no stored override exists" do
      expect(notification.stored_override_present).to be(false)
      expect(notification.inbox_enabled).to be(true)
      expect(notification.channels).to eq("email" => true, "sms" => true)
      expect(notification.available_channels).to eq(["email"])
      expect(notification.allowed_channels).to eq(%w[email sms])
      expect(notification.configurable).to be(true)
      expect(notification.mandatory).to be(false)
    end

    context "when email is not validated" do
      before { user.update!(email_validated: false) }

      it "intersects available_channels with recipient_ready" do
        expect(notification.available_channels).to eq([])
      end
    end

    context "with a stored override" do
      before do
        CommandTower::Messaging::Preferences.upsert_stored!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(channels: { "email" => false }, inbox: false),
        )
      end

      it "maps stored overrides through Resolve" do
        expect(notification.stored_override_present).to be(true)
        expect(notification.inbox_enabled).to be(false)
        expect(notification.channels).to eq("email" => false, "sms" => true)
      end
    end

    context "for a mandatory non-configurable type" do
      let(:notification_type_key) { "password.changed" }

      it "exposes mandatory and non-configurable presentation flags" do
        expect(notification.configurable).to be(false)
        expect(notification.mandatory).to be(true)
        expect(notification.stored_override_present).to be(false)
      end
    end

    it "returns an immutable catalog result" do
      expect(catalog).to be_frozen
      expect(catalog.categories).to be_frozen
      expect(catalog.categories.first).to be_frozen
      expect(catalog.categories.first.notifications).to be_frozen
    end

    context "when Store raises" do
      before do
        allow(CommandTower::Messaging::Preferences::Store).to receive(:find).and_raise(
          CommandTower::Messaging::Preferences::StoreError,
          "db down",
        )
      end

      it "fails closed when Store raises" do
        expect { catalog }.to raise_error(CommandTower::Messaging::Preferences::StoreError)
      end
    end
  end

  describe "Preferences.catalog façade" do
    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(settings_visible: true),
      )
    end

    subject(:result) do
      CommandTower::Messaging::Preferences.catalog(
        recipient_id: user.id,
        platform_enabled_channels: [],
      )
    end

    it "delegates to Catalog" do
      expect(result).to be_a(CommandTower::Messaging::Preferences::CatalogResult)
      expect(result.categories.length).to eq(1)
    end
  end
end
