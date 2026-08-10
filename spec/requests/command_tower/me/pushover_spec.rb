# frozen_string_literal: true

RSpec.describe "Me pushover", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:credentials) do
    {
      userKey: "pushover-user-key-abcd",
      applicationToken: "pushover-app-token-zzzz"
    }
  end

  let(:with_pushover_fake_adapter!) do
    lambda do |&block|
      previous = CommandTower.config.messaging.pushover.adapter
      CommandTower.config.messaging.pushover.adapter = "fake"
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
      block.call
    ensure
      CommandTower.config.messaging.pushover.adapter = previous
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
    end
  end

  before do
    allow(CommandTower::Services::Me::PushoverProductGate).to receive(:enabled?).and_return(true)
  end

  it "rejects unauthenticated show" do
    get "/me/pushover"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns unconfigured when no endpoint exists" do
    get "/me/pushover", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to include(
      "configured" => false,
      "actions" => {
        "canCreate" => true,
        "canVerify" => false,
        "canReplace" => false,
        "canRemove" => false
      }
    )
  end

  context "when managing pushover credentials end-to-end" do
    around { |example| with_pushover_fake_adapter!.call { example.run } }

    context "after creating credentials" do
      before { post "/me/pushover", headers: headers, params: credentials, as: :json }

      it { expect(response).to have_http_status(:ok) }

      it "returns configured unverified state without secrets" do
        expect(response.parsed_body["data"]).to include(
          "configured" => true,
          "channelKey" => "pushover",
          "verificationState" => "unverified"
        )
        expect(response.parsed_body["data"].to_json).not_to include("pushover-user-key")
        expect(response.parsed_body["data"].to_json).not_to include("pushover-app-token")
      end
    end

    context "after verifying credentials" do
      before do
        post "/me/pushover", headers: headers, params: credentials, as: :json
        post "/me/pushover/verification", headers: headers, as: :json
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.parsed_body.dig("data", "verificationState")).to eq("verified") }
    end

    context "after replacing via PUT" do
      let(:original_id) do
        post "/me/pushover", headers: headers, params: credentials, as: :json
        response.parsed_body["data"]["id"]
      end

      before do
        original_id
        post "/me/pushover/verification", headers: headers, as: :json
        put "/me/pushover",
            headers: headers,
            params: {
              userKey: "pushover-user-key-efgh",
              applicationToken: "pushover-app-token-yyyy"
            },
            as: :json
      end

      it { expect(response).to have_http_status(:ok) }

      it "creates a new endpoint in unverified state" do
        expect(response.parsed_body["data"]["id"]).not_to eq(original_id)
        expect(response.parsed_body["data"]["verificationState"]).to eq("unverified")
      end
    end

    context "after patch and delete" do
      before do
        post "/me/pushover", headers: headers, params: credentials, as: :json
        post "/me/pushover/verification", headers: headers, as: :json
        put "/me/pushover",
            headers: headers,
            params: {
              userKey: "pushover-user-key-efgh",
              applicationToken: "pushover-app-token-yyyy"
            },
            as: :json
        patch "/me/pushover",
              headers: headers,
              params: {
                userKey: "pushover-user-key-ijkl",
                applicationToken: "pushover-app-token-xxxx"
              },
              as: :json
        delete "/me/pushover", headers: headers
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.parsed_body.dig("data", "configured")).to eq(false) }
    end
  end

  it "rejects missing credentials with 422" do
    post "/me/pushover", headers: headers, params: { userKey: "" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "maps conflict when already configured" do
    with_pushover_fake_adapter!.call do
      post "/me/pushover", headers: headers, params: credentials, as: :json
      expect(response).to have_http_status(:ok)

      post "/me/pushover",
           headers: headers,
           params: {
             userKey: "pushover-user-key-efgh",
             applicationToken: "pushover-app-token-yyyy"
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("pushover_already_configured")
    end
  end

  it "maps verification failures" do
    with_pushover_fake_adapter!.call do
      post "/me/pushover", headers: headers, params: credentials, as: :json

      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user
      post "/me/pushover/verification", headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("pushover_invalid_user")

      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :provider_unavailable
      post "/me/pushover/verification", headers: headers, as: :json
      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("pushover_provider_unavailable")
    end
  end

  context "when Pushover product gate is off" do
    before do
      allow(CommandTower::Services::Me::PushoverProductGate).to receive(:enabled?).and_return(false)
    end

    it "returns service unavailable when Pushover product gate is off" do
      get "/me/pushover", headers: headers

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("pushover_capability_unavailable")
    end

    it "does not apply Engine Pushover route constraints" do
      expect(CommandTower::Engine.routes.recognize_path("/me/pushover", method: :get)).to include(
        controller: "command_tower/me/pushover",
        action: "show"
      )
      expect(CommandTower::Engine.routes.recognize_path("/me/pushover", method: :put)).to include(
        controller: "command_tower/me/pushover",
        action: "update"
      )
      expect(CommandTower::Engine.routes.recognize_path("/me/pushover/verification", method: :post)).to include(
        controller: "command_tower/me/pushover/verifications",
        action: "create"
      )
    end
  end
end
