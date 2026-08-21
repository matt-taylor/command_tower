# frozen_string_literal: true

RSpec.describe "GET /admin/users/assignable-roles", :with_rbac_setup, type: :request do
  let(:rbac_admin) { create(:user, :role_rbac_admin) }
  let(:identity_admin) { create(:user, :role_users_identity_admin) }
  let(:headers) { authenticate_request_with_bearer!(rbac_admin) }

  context "without authentication" do
    before { get "/admin/users/assignable-roles" }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "when the principal can update identity but not RBAC" do
    let(:headers) { authenticate_request_with_bearer!(identity_admin) }

    before { get "/admin/users/assignable-roles", headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when the principal can assign roles" do
    before { get "/admin/users/assignable-roles", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns the assignable catalog envelope without owner" do
      expect(response.parsed_body.keys).to contain_exactly("data", "meta", "errors")
      expect(response.parsed_body.fetch("errors")).to eq([])
      expect(response.parsed_body.dig("data", "roles").map { |row| row.fetch("name") }).to include(
        "member",
        "support_admin",
        "rbac_admin"
      )
      expect(response.parsed_body.dig("data", "roles").map { |row| row.fetch("name") }).not_to include("owner")
    end
  end
end

RSpec.describe "PATCH /admin/users/:id/roles", :with_rbac_setup, type: :request do
  let(:rbac_admin) { create(:user, :role_rbac_admin) }
  let(:identity_admin) { create(:user, :role_users_identity_admin) }
  let(:member) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(rbac_admin) }
  let(:user_keys) do
    %w[
      id firstName lastName fullName username email emailValidated
      phoneNumber phoneNumberValidated roles createdAt
    ]
  end
  let(:params) { { roles: %w[member support_admin] } }

  context "without authentication" do
    before { patch "/admin/users/#{member.id}/roles", params: { roles: ["member"] }, as: :json }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "when the principal can update identity but not RBAC" do
    let(:headers) { authenticate_request_with_bearer!(identity_admin) }

    before { patch "/admin/users/#{member.id}/roles", params: params, headers: headers, as: :json }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when the update is valid" do
    before { patch "/admin/users/#{member.id}/roles", params: params, headers: headers, as: :json }

    it { expect(response).to have_http_status(:ok) }

    it "returns the Show user envelope" do
      expect(response.parsed_body.keys).to contain_exactly("data", "meta", "errors")
      expect(response.parsed_body.fetch("errors")).to eq([])
      expect(response.parsed_body.fetch("data").keys).to match_array(user_keys)
      expect(response.parsed_body.dig("data", "roles")).to contain_exactly("member", "support_admin")
    end
  end

  context "when the body is invalid" do
    before do
      patch "/admin/users/#{member.id}/roles",
        params: { roles: "member" },
        headers: headers,
        as: :json
    end

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns a validation envelope" do
      expect(response.parsed_body.fetch("data")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("validation_failed")
    end
  end

  context "when the user is missing" do
    before do
      patch "/admin/users/#{User.maximum(:id).to_i + 1}/roles",
        params: { roles: ["member"] },
        headers: headers,
        as: :json
    end

    it { expect(response).to have_http_status(:not_found) }

    it { expect(response.parsed_body.fetch("data")).to be_nil }
  end
end
