# frozen_string_literal: true

RSpec.describe "POST /admin/users/:id/impersonation-sessions", :with_rbac_setup, type: :request do
  let(:target) { create(:user, roles: ["member"]) }
  let(:operator) { create(:user, :role_impersonation_operator) }
  let(:admin) { create(:user, :role_admin) }
  let(:headers) { authenticate_request_with_bearer!(operator) }

  it "rejects unauthenticated requests" do
    post "/admin/users/#{target.id}/impersonation-sessions"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the caller has users but not impersonation" do
    let(:headers) { authenticate_request_with_bearer!(admin) }

    before { post "/admin/users/#{target.id}/impersonation-sessions", headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when an impersonation operator starts a session" do
    before { post "/admin/users/#{target.id}/impersonation-sessions", headers: headers }

    it { expect(response).to have_http_status(:created) }

    it "returns session clocks and identities" do
      expect(response.parsed_body.fetch("data").fetch("actorUserId")).to eq(operator.id)
      expect(response.parsed_body.fetch("data").fetch("targetUserId")).to eq(target.id)
      expect(response.parsed_body.fetch("data").fetch("id")).to be_present
      expect(response.parsed_body.fetch("data").fetch("idleExpiresAt")).to be_present
      expect(response.parsed_body.fetch("data").fetch("absoluteExpiresAt")).to be_present
    end

    it "sets a replacement token overlaying the administrator JWT" do
      expect(
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload[:user_id]
      ).to eq(operator.id)
      expect(
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload[:impersonation_session_id]
      ).to eq(response.parsed_body.dig("data", "id"))
    end
  end

  context "when targeting self" do
    before { post "/admin/users/#{operator.id}/impersonation-sessions", headers: headers }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "when nested impersonation is attempted" do
    let!(:session) { create(:impersonation_session, actor: operator, target:) }
    let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }
    let(:other) { create(:user, roles: ["member"]) }

    before { post "/admin/users/#{other.id}/impersonation-sessions", headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when an owner impersonates another owner and tries to nest" do
    let(:actor) { create(:user, :role_owner) }
    let(:nested_target) { create(:user, :role_owner) }
    let(:other) { create(:user, :role_owner) }
    let!(:session) { create(:impersonation_session, actor:, target: nested_target) }
    let(:headers) { authenticate_impersonation_with_bearer!(actor, session) }

    before { post "/admin/users/#{other.id}/impersonation-sessions", headers: headers }

    it { expect(response).to have_http_status(418) }

    it "does not start a nested session" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("admin_unavailable_during_impersonation")
      expect(CommandTower::Impersonation::Session.open.where(target_user_id: other.id).count).to eq(0)
    end
  end

  context "with foundation-proof admin scoping" do
    let(:member_a) { create(:user, roles: ["member"], email: "imp-a@example.com", username: "impa") }
    let(:member_b) { create(:user, roles: ["member"], email: "imp-b@example.com", username: "impb") }

    before do
      register_foundation_proof_scoped_admin!
      seed_foundation_proof_partitions!(admin: operator, member_a:, member_b:)
    end

    context "when starting an in-scope user" do
      before do
        post "/admin/users/#{member_a.id}/impersonation-sessions",
          params: { partition: "scope-a" },
          headers: headers
      end

      it { expect(response).to have_http_status(:created) }

      it "creates an impersonation session" do
        expect(CommandTower::Impersonation::Session.open.where(target_user_id: member_a.id).count).to eq(1)
      end
    end

    context "when starting an out-of-scope user via a valid scope param" do
      before do
        post "/admin/users/#{member_b.id}/impersonation-sessions",
          params: { partition: "scope-a" },
          headers: headers
      end

      it { expect(response).to have_http_status(:not_found) }

      it "does not create an impersonation session" do
        expect(CommandTower::Impersonation::Session.where(target_user_id: member_b.id).count).to eq(0)
      end
    end

    context "when the required scope is missing" do
      before do
        post "/admin/users/#{member_a.id}/impersonation-sessions", headers: headers
      end

      it { expect(response).to have_http_status(:forbidden) }

      it "does not create an impersonation session" do
        expect(CommandTower::Impersonation::Session.where(actor_user_id: operator.id).count).to eq(0)
      end
    end

    context "when the scope is invalid" do
      before do
        post "/admin/users/#{member_a.id}/impersonation-sessions",
          params: { partition: "not-a-partition" },
          headers: headers
      end

      it { expect(response).to have_http_status(:forbidden) }

      it "does not create an impersonation session" do
        expect(CommandTower::Impersonation::Session.where(actor_user_id: operator.id).count).to eq(0)
      end
    end

    context "when a crafted POST targets another user id in a valid scope" do
      before do
        post "/admin/users/#{member_b.id}/impersonation-sessions",
          params: { partition: "scope-a" },
          headers: headers
      end

      it "cannot bypass the scoped Users relation" do
        expect(response).to have_http_status(:not_found)
        expect(CommandTower::Impersonation::Session.where(target_user_id: member_b.id).count).to eq(0)
      end
    end
  end
end
