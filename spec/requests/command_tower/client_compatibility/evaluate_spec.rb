# frozen_string_literal: true

RSpec.describe "Client version compatibility boundary", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:auth_headers) { authenticate_request_with_bearer!(user) }

  describe "GET /auth/session (observe mode, dummy default)" do
    subject(:make_request) { get "/auth/session", headers: headers }

    context "with no client-version headers at all" do
      let(:headers) { auth_headers }

      it "continues normally (today's status)" do
        make_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "with an app version below the dummy web minimum" do
      let(:headers) { auth_headers.merge("X-App-Version" => "0.1.0", "X-Client-Platform" => "web") }

      it "still continues — observe mode never blocks" do
        make_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "with a partial (malformed) X-App-Version" do
      let(:headers) { auth_headers.merge("X-App-Version" => "1.2", "X-Client-Platform" => "web") }

      it "still continues in observe mode" do
        make_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the role grant is missing" do
      let(:user) { create(:user, roles: []) }
      let(:headers) { auth_headers.merge("X-App-Version" => "9.9.9", "X-Client-Platform" => "web") }

      it "still returns forbidden — a satisfied version does not bypass RBAC" do
        make_request

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /auth/session (enforce mode)" do
    subject(:make_request) { get "/auth/session", headers: headers }

    before { CommandTower.config.registry.client_compatibility.mode = :enforce }

    context "with an app version below the configured minimum" do
      let(:headers) { auth_headers.merge("X-App-Version" => "0.1.0", "X-Client-Platform" => "web") }

      before { make_request }

      let(:error) { response.parsed_body["errors"].first }

      it "returns 426 upgrade required" do
        expect(response).to have_http_status(:upgrade_required)
      end

      it "returns the client_update_required error envelope with camelCase details" do
        expect(error).to include("code" => "client_update_required", "message" => "Client update required")
        expect(error["details"]).to include(
          "platform" => "web",
          "scope" => "application",
          "currentVersion" => "0.1.0",
          "minimumVersion" => "1.0.0",
          "recovery" => "reload"
        )
      end
    end

    context "with a partial (malformed) X-App-Version" do
      let(:headers) { auth_headers.merge("X-App-Version" => "1.2", "X-Client-Platform" => "web") }

      it "is treated as invalid identity, not a Gem::Version comparison, and still returns application-scoped 426" do
        make_request

        expect(response).to have_http_status(:upgrade_required)
        expect(response.parsed_body["errors"].first["details"]).to include("scope" => "application")
      end
    end

    context "with a recognized but unconfigured platform (android)" do
      let(:headers) { auth_headers.merge("X-App-Version" => "9.9.9", "X-Client-Platform" => "android") }

      it "returns an application-scoped 426" do
        make_request

        expect(response).to have_http_status(:upgrade_required)
        expect(response.parsed_body["errors"].first["details"]).to include("scope" => "application")
      end
    end

    context "with an app version satisfying the configured minimum" do
      let(:headers) { auth_headers.merge("X-App-Version" => "1.0.0", "X-Client-Platform" => "web") }

      it "continues to the product workflow" do
        make_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the version is fine but the RBAC grant is missing" do
      let(:user) { create(:user, roles: []) }
      let(:headers) { auth_headers.merge("X-App-Version" => "9.9.9", "X-Client-Platform" => "web") }

      it "still returns forbidden (403), not 426" do
        make_request

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "recommended-update meta on success envelopes" do
    before do
      CommandTower.config.registry.client_compatibility.reset_host_definitions!
      CommandTower.config.registry.client_compatibility.platform(:web) do |p|
        p.minimum = "1.0.0"
        p.recommended = "1.5.0"
      end
    end

    context "GET /auth/session" do
      subject(:make_request) { get "/auth/session", headers: headers }

      let(:headers) { auth_headers.merge("X-App-Version" => "1.2.0", "X-Client-Platform" => "web") }

      before { make_request }

      it "includes meta.clientCompatibility with the recommended version" do
        expect(response.parsed_body["meta"]).to include(
          "clientCompatibility" => hash_including("recommendedVersion" => "1.5.0", "updateAvailable" => true)
        )
      end
    end

    context "POST /auth/plain-text/login" do
      subject(:make_request) { post "/auth/plain-text/login", params: params, headers: headers, as: :json }

      let(:password) { "password1234" }
      let(:user) { create(:user, password: password, roles: ["member"]) }
      let(:params) { { identifier: user.email, password: password } }
      let(:headers) { { "X-App-Version" => "1.2.0", "X-Client-Platform" => "web" } }

      before { make_request }

      it "includes meta.clientCompatibility with the recommended version" do
        expect(response.parsed_body["meta"]).to include(
          "clientCompatibility" => hash_including("recommendedVersion" => "1.5.0", "updateAvailable" => true)
        )
      end
    end

    context "GET /me (a success payload that is not login/session)" do
      subject(:make_request) { get "/me", headers: headers }

      let(:headers) { auth_headers.merge("X-App-Version" => "1.2.0", "X-Client-Platform" => "web") }

      before { make_request }

      it "omits clientCompatibility meta" do
        expect(response.parsed_body["meta"].to_h).not_to have_key("clientCompatibility")
      end
    end
  end
end
