# frozen_string_literal: true

RSpec.describe "Impersonation session overlay", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator, first_name: "Admin", last_name: "Actor") }
  let(:target) { create(:user, roles: ["member"], first_name: "Pat", last_name: "Target") }
  let!(:session) do
    create(
      :impersonation_session,
      actor: operator,
      target:,
      idle_expires_at: 2.minutes.from_now,
      absolute_expires_at: 1.hour.from_now
    )
  end
  let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }

  context "when the product profile is fetched" do
    before { get "/profile", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "runs as the target" do
      expect(response.parsed_body.dig("data", "id")).to eq(target.id)
      expect(response.parsed_body.dig("data", "firstName")).to eq("Pat")
    end
  end

  context "when GET /profile succeeds" do
    let!(:idle_before) { session.idle_expires_at }
    let!(:absolute_before) { session.absolute_expires_at }

    before { get "/profile", headers: headers }

    it "refreshes idle and leaves absolute unchanged" do
      expect(session.reload.idle_expires_at).to be > idle_before
      expect(session.absolute_expires_at.to_i).to eq(absolute_before.to_i)
    end

    it "echoes authoritative clocks only after idle refresh" do
      expect(response.parsed_body.dig("meta", "impersonation").fetch("idleExpiresAt")).to be_present
      expect(response.parsed_body.dig("meta", "impersonation").fetch("absoluteExpiresAt")).to be_present
    end
  end

  context "when PATCH /me/name succeeds" do
    let!(:idle_before) { session.idle_expires_at }

    before do
      patch "/me/name",
        headers: headers,
        params: { firstName: "New", lastName: "Name" },
        as: :json
    end

    it { expect(response).to have_http_status(:ok) }

    it "refreshes idle on a non-GET verb" do
      expect(session.reload.idle_expires_at).to be > idle_before
    end
  end

  context "when GET /auth/session succeeds" do
    let!(:idle_before) { session.idle_expires_at }

    before { get "/auth/session", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "does not refresh idle" do
      expect(session.reload.idle_expires_at.to_i).to eq(idle_before.to_i)
    end

    it "projects impersonation clocks without idle-refresh meta" do
      expect(response.parsed_body.dig("data", "impersonation")).to include(
        "active" => true,
        "sessionId" => session.id,
        "actorUserId" => operator.id,
        "actorDisplayName" => "Admin Actor",
        "targetUserId" => target.id
      )
      expect(response.parsed_body.dig("data", "impersonation", "idleExpiresAt")).to be_present
      expect(response.parsed_body.dig("data", "impersonation", "absoluteExpiresAt")).to be_present
      expect(response.parsed_body.dig("meta", "impersonation")).to be_nil
    end
  end

  context "when PATCH /me/name fails validation" do
    let!(:idle_before) { session.idle_expires_at }

    before do
      patch "/me/name", headers: headers, params: { firstName: "" }, as: :json
    end

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "does not refresh idle" do
      expect(session.reload.idle_expires_at.to_i).to eq(idle_before.to_i)
    end
  end

  context "when the idle clock has expired" do
    let!(:session) do
      create(
        :impersonation_session,
        actor: operator,
        target:,
        idle_expires_at: 1.minute.ago,
        absolute_expires_at: 1.hour.from_now
      )
    end

    before { get "/profile", headers: headers }

    it "rejects the product request without clearing a missing cookie" do
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("impersonation_session_expired")
      expect(response.headers["Set-Cookie"].to_s).not_to include(CommandTower.config.jwt.cookie.name)
    end
  end

  context "when two concurrent sessions exist" do
    let(:other_target) { create(:user, roles: ["member"], first_name: "Other") }
    let!(:other_session) { create(:impersonation_session, actor: operator, target: other_target) }
    let(:other_headers) { authenticate_impersonation_with_bearer!(operator, other_session) }

    before do
      get "/profile", headers: headers
      @first_body = response.parsed_body
      get "/profile", headers: other_headers
    end

    it "isolates effective identity per session" do
      expect(@first_body.dig("data", "id")).to eq(target.id)
      expect(response.parsed_body.dig("data", "id")).to eq(other_target.id)
      expect(session.reload.open?).to be(true)
      expect(other_session.reload.open?).to be(true)
    end
  end
end
