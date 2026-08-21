# frozen_string_literal: true

RSpec.describe "Admin Users scoping", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member_a) { create(:user, roles: ["member"], email: "member-a@example.com", username: "membera") }
  let(:member_b) { create(:user, roles: ["member"], email: "member-b@example.com", username: "memberb") }
  let(:headers) { authenticate_request_with_bearer!(admin) }

  before do
    register_foundation_proof_scoped_admin!
    seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
  end

  describe "GET /admin/users" do
    context "when partition scope is missing" do
      before { get "/admin/users", headers: headers }

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when partition scope is invalid" do
      before { get "/admin/users", params: { partition: "scope-z" }, headers: headers }

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when scoped to scope-a" do
      before { get "/admin/users", params: { partition: "scope-a" }, headers: headers }

      subject(:user_ids) { response.parsed_body.fetch("data").map { |row| row.fetch("id") } }

      it { expect(response).to have_http_status(:ok) }

      it "returns only users in scope-a" do
        expect(user_ids).to include(admin.id, member_a.id)
        expect(user_ids).not_to include(member_b.id)
      end

      it "counts only scoped users" do
        expect(response.parsed_body.dig("meta", "totalCount")).to eq(2)
      end
    end

    context "when search would match an out-of-scope user" do
      before do
        get "/admin/users", params: { partition: "scope-a", search: "member-b" }, headers: headers
      end

      subject(:user_ids) { response.parsed_body.fetch("data").map { |row| row.fetch("id") } }

      it { expect(response).to have_http_status(:ok) }

      it "does not surface out-of-scope matches" do
        expect(user_ids).not_to include(member_b.id)
      end
    end
  end

  describe "GET /admin/users/:id" do
    context "when the user is outside the scoped partition" do
      before do
        get "/admin/users/#{member_b.id}", params: { partition: "scope-a" }, headers: headers
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the user id does not exist" do
      before do
        get "/admin/users/999999999", params: { partition: "scope-a" }, headers: headers
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the user is inside the scoped partition" do
      before do
        get "/admin/users/#{member_a.id}", params: { partition: "scope-a" }, headers: headers
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns the in-scope user" do
        expect(response.parsed_body.dig("data", "id")).to eq(member_a.id)
      end
    end
  end

  describe "PATCH /admin/users/:id/name" do
    context "when partition scope is missing" do
      before do
        patch "/admin/users/#{member_a.id}/name",
          params: { firstName: "Ada", lastName: "Lovelace" },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when the user is outside the scoped partition" do
      before do
        patch "/admin/users/#{member_b.id}/name?partition=scope-a",
          params: { firstName: "Ada", lastName: "Lovelace" },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe "PATCH /admin/users/:id/roles" do
    context "when partition scope is missing" do
      before do
        patch "/admin/users/#{member_a.id}/roles",
          params: { roles: ["member"] },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when the user is outside the scoped partition" do
      before do
        patch "/admin/users/#{member_b.id}/roles?partition=scope-a",
          params: { roles: ["member"] },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
