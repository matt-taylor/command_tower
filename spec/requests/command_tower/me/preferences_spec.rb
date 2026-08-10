# frozen_string_literal: true

RSpec.describe "Me preferences", :with_rbac_setup, :messaging_preferences, type: :request do
  let(:user) { create(:user, roles: ["member"], email: "prefs-ct@example.com") }
  let(:headers) { authenticate_request_with_bearer!(user) }

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
        allowed_channels: %w[email sms],
        default_channels: %w[email],
        default_preference_state: {
          "channels" => { "email" => true, "sms" => false },
          "inbox" => true,
        },
        settings_visible: true,
        user_configurable: true,
      ),
      build_notification_type_declaration(
        key: "password_changed",
        label: "Password Changed",
        category_key: "account",
        category_label: "Account",
        category_order: 30,
        type_order: 10,
        allowed_channels: %w[email],
        default_channels: %w[email],
        default_preference_state: {
          "channels" => { "email" => true },
          "inbox" => true,
        },
        settings_visible: true,
        user_configurable: false,
        mandatory: true,
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

  describe "GET /me/preferences" do
    it "rejects unauthenticated requests" do
      get "/me/preferences"

      expect(response).to have_http_status(:unauthorized)
    end

    context "when the caller lacks roles" do
      let(:unprivileged_user) { create(:user, roles: []) }
      let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

      before { get "/me/preferences", headers: unprivileged_headers }

      it { expect(response).to have_http_status(:forbidden) }
    end

    it "returns ordered settings-visible categories with defaults" do
      get "/me/preferences", headers: headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data.keys).to contain_exactly("categories")
      expect(data["categories"].map { |c| c["key"] }).to eq(%w[reservations account])
      expect(data["categories"].flat_map { |c| c["notifications"].map { |n| n["key"] } }).not_to include("hello_world")

      booking = data["categories"].first["notifications"].first
      expect(booking).to include(
        "key" => "booking_confirmation",
        "allowedChannels" => %w[email sms],
        "availableChannels" => ["email"],
      )
      expect(booking["preferences"]).to include(
        "inboxEnabled" => true,
        "storedOverridePresent" => false,
      )
    end

    it "reflects stored overrides" do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key: "booking_confirmation",
        preference_state: { "channels" => { "email" => false }, "inbox" => false },
      )

      get "/me/preferences", headers: headers

      booking = response.parsed_body.dig("data", "categories", 0, "notifications", 0)
      expect(booking["preferences"]).to include(
        "inboxEnabled" => false,
        "storedOverridePresent" => true,
      )
    end
  end

  describe "PATCH /me/preferences/:notification_type_key" do
    it "updates preferences and returns the notification shape" do
      patch "/me/preferences/booking_confirmation",
            headers: headers,
            params: { preferences: { inboxEnabled: false, channels: { email: false } } },
            as: :json

      expect(response).to have_http_status(:ok)
      notification = response.parsed_body.dig("data", "notification")
      expect(notification["key"]).to eq("booking_confirmation")
      expect(notification["preferences"]).to include(
        "inboxEnabled" => false,
        "storedOverridePresent" => true,
      )
    end

    it "resets to defaults when preferences is empty" do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key: "booking_confirmation",
        preference_state: { "channels" => { "email" => false }, "inbox" => false },
      )

      patch "/me/preferences/booking_confirmation",
            headers: headers,
            params: { preferences: {} },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "notification", "preferences", "storedOverridePresent")).to eq(false)
    end

    it "returns not found for unknown types" do
      patch "/me/preferences/missing_type",
            headers: headers,
            params: { preferences: { inboxEnabled: false } },
            as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for settings-hidden types" do
      patch "/me/preferences/hello_world",
            headers: headers,
            params: { preferences: { inboxEnabled: false } },
            as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable entity for non-configurable types" do
      patch "/me/preferences/password_changed",
            headers: headers,
            params: { preferences: { channels: { email: false } } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns unprocessable entity for channels outside the allowed set" do
      patch "/me/preferences/booking_confirmation",
            headers: headers,
            params: { preferences: { channels: { push: false } } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns unprocessable entity for malformed bodies" do
      patch "/me/preferences/booking_confirmation",
            headers: headers,
            params: { preferences: { mandatory: true } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
