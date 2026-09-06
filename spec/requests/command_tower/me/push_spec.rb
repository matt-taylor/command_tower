# frozen_string_literal: true

RSpec.describe "Me push", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:token) { "ExponentPushToken[reqaaaa1111]" }
  let(:params) { { token: } }

  let(:with_expo_fake_adapter!) do
    lambda do |&block|
      previous = CommandTower.config.messaging.expo.adapter
      CommandTower.config.messaging.expo.adapter = "fake"
      block.call
    ensure
      CommandTower.config.messaging.expo.adapter = previous
    end
  end

  before do
    allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(true)
  end

  it "rejects unauthenticated index" do
    get "/me/push"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the caller lacks roles" do
    let(:unprivileged_user) { create(:user, roles: []) }
    let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

    before { get "/me/push", headers: unprivileged_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "returns an empty collection when no endpoints exist" do
    get "/me/push", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq("endpoints" => [])
  end

  context "when managing push tokens end-to-end" do
    around { |example| with_expo_fake_adapter!.call { example.run } }

    context "after creating a token" do
      before { post "/me/push", headers: headers, params:, as: :json }

      it { expect(response).to have_http_status(:ok) }

      it "returns a verified active endpoint without the token" do
        expect(response.parsed_body["data"]).to include(
          "channelKey" => "push",
          "lifecycleState" => "active",
          "verificationState" => "verified",
        )
        expect(response.parsed_body["data"].to_json).not_to include("ExponentPushToken")
      end
    end

    context "after idempotent second POST of the same token" do
      before do
        post "/me/push", headers: headers, params:, as: :json
        @first_id = response.parsed_body.dig("data", "id")
        post "/me/push", headers: headers, params:, as: :json
      end

      it "returns the same verified endpoint" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "id")).to eq(@first_id)
        expect(response.parsed_body.dig("data", "verificationState")).to eq("verified")
      end
    end

    context "after replace via PUT" do
      let(:original_id) do
        post "/me/push", headers: headers, params:, as: :json
        response.parsed_body.dig("data", "id")
      end

      before do
        original_id
        put "/me/push/#{original_id}",
            headers: headers,
            params: { token: "ExponentPushToken[reqbbbb2222]" },
            as: :json
      end

      it "creates a new verified endpoint and retires the prior row" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "id")).not_to eq(original_id)
        expect(response.parsed_body.dig("data", "verificationState")).to eq("verified")
        expect(CommandTower::Messaging::Endpoint.find(original_id).lifecycle_state).to eq("retired")
      end
    end

    context "after DELETE" do
      let(:endpoint_id) do
        post "/me/push", headers: headers, params:, as: :json
        response.parsed_body.dig("data", "id")
      end

      before do
        endpoint_id
        delete "/me/push/#{endpoint_id}", headers: headers
      end

      it "revokes the endpoint" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "lifecycleState")).to eq("revoked")
      end
    end

    context "when listing after create and revoke" do
      before do
        post "/me/push", headers: headers, params:, as: :json
        active_id = response.parsed_body.dig("data", "id")
        post "/me/push",
             headers: headers,
             params: { token: "ExponentPushToken[reqcccc3333]" },
             as: :json
        second_id = response.parsed_body.dig("data", "id")
        delete "/me/push/#{active_id}", headers: headers
        get "/me/push", headers: headers
        @listed_ids = response.parsed_body.dig("data", "endpoints").map { |row| row["id"] }
        @second_id = second_id
      end

      it "lists only active endpoints" do
        expect(response).to have_http_status(:ok)
        expect(@listed_ids).to eq([@second_id])
      end
    end
  end

  it "rejects missing token with 422" do
    post "/me/push", headers: headers, params: { token: "" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects non-Expo tokens with 422" do
    post "/me/push", headers: headers, params: { token: "plain-device-token" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  context "when push product gate is off" do
    before do
      allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(false)
    end

    it "returns service unavailable" do
      get "/me/push", headers: headers

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("push_capability_unavailable")
    end

    it "keeps routes always drawn" do
      expect(CommandTower::Engine.routes.recognize_path("/me/push", method: :get)).to include(
        controller: "command_tower/me/push",
        action: "index",
      )
      expect(CommandTower::Engine.routes.recognize_path("/me/push/test", method: :post)).to include(
        controller: "command_tower/me/push",
        action: "test",
      )
      expect(CommandTower::Engine.routes.recognize_path("/me/push/1", method: :put)).to include(
        controller: "command_tower/me/push",
        action: "update",
      )
      expect(CommandTower::Engine.routes.recognize_path("/me/push/1", method: :delete)).to include(
        controller: "command_tower/me/push",
        action: "destroy",
      )
    end
  end

  context "POST /me/push/test", :messaging_notification_types do
    let(:push_delivery_test) do
      build_notification_type_declaration(
        key: "push_delivery_test",
        allowed_channels: %w[push],
        default_channels: %w[push],
        inbox_available: false,
        user_configurable: false,
        mandatory: false,
        default_preference_state: {
          "channels" => { "push" => true },
          "inbox" => false,
        },
        label: "Push delivery test",
        category_key: "system",
        category_label: "System",
        category_order: 1,
        type_order: 1,
        settings_visible: false,
      )
    end
    let(:previous_limit) { CommandTower.config.messaging.expo.self_test_per_user_hour }
    let(:previous_channels) { CommandTower.config.messaging.platform_enabled_channels }

    around do |example|
      with_expo_fake_adapter!.call do
        CommandTower.config.messaging.allow_fake_adapter = true
        CommandTower.config.messaging.expo.self_test_per_user_hour = 2
        CommandTower.config.messaging.platform_enabled_channels = -> { %w[inbox push] }
        register_and_seal_notification_types(push_delivery_test)
        example.run
      ensure
        CommandTower.config.messaging.expo.self_test_per_user_hour = previous_limit
        CommandTower.config.messaging.platform_enabled_channels = previous_channels
      end
    end

    context "when no endpoint is registered" do
      before { post "/me/push/test", headers: headers, as: :json }

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it "returns push_test_no_endpoint" do
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("push_test_no_endpoint")
      end
    end

    context "when an endpoint is registered" do
      before do
        post "/me/push", headers: headers, params:, as: :json
        post "/me/push/test", headers: headers, as: :json
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns Produce identifiers without Expo tokens" do
        expect(response.parsed_body["data"]).to include(
          "communicationId" => a_kind_of(Integer).or(a_kind_of(String)),
          "selectedChannels" => a_collection_including("push"),
        )
        expect(response.parsed_body.to_json).not_to include("ExponentPushToken")
      end
    end

    context "when the configured self-test limit is exceeded" do
      before do
        post "/me/push", headers: headers, params:, as: :json
        2.times { post "/me/push/test", headers: headers, as: :json }
        post "/me/push/test", headers: headers, as: :json
      end

      it "returns 429 push_test_rate_limited" do
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("push_test_rate_limited")
      end
    end
  end
end
