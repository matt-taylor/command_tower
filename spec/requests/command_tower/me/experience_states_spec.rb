# frozen_string_literal: true

RSpec.describe "Me experience states", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:complete_params) do
    {
      experienceKey: "welcome",
      scopeType: "example_scope",
      scopeIdentifier: "42",
      version: "v1",
    }
  end

  around do |example|
    previous = CommandTower.config.application.host_key
    CommandTower.config.application.host_key = host_key
    example.run
  ensure
    CommandTower.config.application.host_key = previous
  end

  let(:host_key) { "command_tower" }

  it "rejects unauthenticated index" do
    get "/me/experience-states"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the caller lacks roles" do
    let(:unprivileged_user) { create(:user, roles: []) }
    let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

    before { get "/me/experience-states", headers: unprivileged_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "returns an empty collection when no completions exist" do
    get "/me/experience-states", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq("experienceStates" => [])
    expect(response.body).not_to include("showWelcome")
  end

  context "after completing an experience state" do
    before { post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json }

    it "returns the durable fact" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include(
        "hostKey" => "command_tower",
        "experienceKey" => "welcome",
        "scopeType" => "example_scope",
        "scopeIdentifier" => "42",
        "version" => "v1",
      )
      expect(response.parsed_body.dig("data", "completedAt")).to be_present
      expect(response.body).not_to include("showWelcome")
    end

    it "lists the completed row" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "experienceStates").size).to eq(1)
      expect(response.parsed_body.dig("data", "experienceStates", 0, "scopeIdentifier")).to eq("42")
      expect(response.body).not_to include("showWelcome")
    end
  end

  context "when completing twice" do
    before do
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
      @first_completed_at = response.parsed_body.dig("data", "completedAt")
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
    end

    it "returns the same completedAt" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "completedAt")).to eq(@first_completed_at)
    end
  end

  describe "complete failure statuses" do
    let(:log) { StringIO.new }
    let(:submitted) do
      {
        experienceKey: "sentinel-key-zq91",
        scopeType: "example_scope",
        scopeIdentifier: "sentinel-id-zq92",
        version: "v1",
      }
    end

    before do
      logger = ActiveSupport::Logger.new(log)
      allow(Rails).to receive(:logger).and_return(logger)
      allow(Rails.logger).to receive(:error).and_call_original
    end

    let(:echoed_output) { response.body + log.string }

    context "when impersonating" do
      before do
        allow(CommandTower::Current).to receive(:impersonation_active).and_return(true)
        post "/me/experience-states/complete", headers: headers, params: submitted, as: :json
      end

      it "returns 403" do
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("experience_state_impersonation_forbidden")
      end

      it "does not echo submitted input" do
        expect(echoed_output).not_to match(/sentinel-(key|id)-zq9[12]/)
      end
    end

    context "when rate limited" do
      before do
        allow(CommandTower.config.registry.experience_states).to receive(:complete_rate)
          .and_return({ limit: 1, window: 60 })
        flush_signup_rate_limits!
        post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
        post "/me/experience-states/complete", headers: headers, params: submitted, as: :json
      end

      it "returns 429 with retry_after_seconds" do
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body.dig("errors", 0, "details", "retry_after_seconds")).to be_positive
      end

      it "does not echo submitted input" do
        expect(echoed_output).not_to match(/sentinel-(key|id)-zq9[12]/)
      end
    end

    context "with an unregistered key" do
      before { post "/me/experience-states/complete", headers: headers, params: submitted, as: :json }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("experience_state_unregistered")
      end

      it "does not echo submitted input" do
        expect(echoed_output).not_to match(/sentinel-(key|id)-zq9[12]/)
      end
    end

    context "when the per-user cap is reached" do
      let(:complete_params) { super().merge(scopeIdentifier: "sentinel-id-zq92") }

      before do
        allow(CommandTower.config.registry.experience_states).to receive(:max_rows_per_user).and_return(1)
        create(:user_experience_state, user:, host_key: "command_tower", experience_key: "other",
                                       scope_type: "example_scope", scope_identifier: "1", version: "v1")
        post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
      end

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("experience_state_limit_reached")
      end

      it "does not echo the identifier" do
        expect(echoed_output).not_to include("sentinel-id-zq92")
      end
    end

    context "when replaying an existing fact at the cap" do
      before do
        allow(CommandTower.config.registry.experience_states).to receive(:max_rows_per_user).and_return(1)
        post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
        post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
      end

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "when another host_key row exists" do
    before do
      create(
        :user_experience_state,
        user:,
        host_key: "other_host",
        experience_key: "welcome",
        scope_type: "example_scope",
        scope_identifier: "42",
        version: "v1",
      )
    end

    it "excludes other host rows from the list" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "experienceStates")).to eq([])
    end
  end

  context "when host_key is blank" do
    let(:host_key) { "" }

    it "returns 503 on index" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns 503 on complete" do
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
