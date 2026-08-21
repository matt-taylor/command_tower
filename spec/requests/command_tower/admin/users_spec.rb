# frozen_string_literal: true

RSpec.describe "GET /admin/users", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member) { create(:user, roles: ["member"], email: "member-search@example.com", username: "membersearch") }
  let(:headers) { authenticate_request_with_bearer!(admin) }

  before { member }

  it "rejects unauthenticated requests" do
    get "/admin/users"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests the admin surface" do
    let(:member_headers) { authenticate_request_with_bearer!(member) }

    before { get "/admin/users", headers: member_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "lists users with safe fields and pagination meta" do
    get "/admin/users", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.fetch("data").map { |row| row.fetch("id") }).to include(admin.id, member.id)
    row = body.fetch("data").find { |item| item.fetch("id") == member.id }
    expect(row.keys).to contain_exactly(
      "id", "firstName", "lastName", "fullName", "username", "email",
      "emailValidated", "phoneNumber", "phoneNumberValidated", "roles", "createdAt"
    )
    expect(response.body).not_to include("password_digest")
    expect(response.body).not_to include("verifier_token")
    expect(body.dig("meta", "totalCount")).to be >= 2
    expect(body.dig("meta")).to include("limit", "offset", "totalCount")
  end

  context "when searching by email fragment" do
    before { get "/admin/users", params: { search: "member-search" }, headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns only matching users" do
      ids = response.parsed_body.fetch("data").map { |row| row.fetch("id") }
      expect(ids).to include(member.id)
      expect(ids).not_to include(admin.id)
    end
  end

  context "when paginating" do
    before { get "/admin/users", params: { limit: 1, offset: 0 }, headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "honors limit and reports totalCount" do
      expect(response.parsed_body.fetch("data").length).to eq(1)
      expect(response.parsed_body.dig("meta", "limit")).to eq(1)
      expect(response.parsed_body.dig("meta", "totalCount")).to be >= 2
    end
  end

  it "rejects an invalid limit with 422" do
    get "/admin/users", params: { limit: 0 }, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

RSpec.describe "GET /admin/users/:id", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(admin) }

  it "rejects unauthenticated requests" do
    get "/admin/users/#{member.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests another user" do
    let(:member_headers) { authenticate_request_with_bearer!(member) }

    before { get "/admin/users/#{admin.id}", headers: member_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "shows a user with safe fields" do
    get "/admin/users/#{member.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").fetch("id")).to eq(member.id)
    expect(response.parsed_body.fetch("data").fetch("email")).to eq(member.email)
    expect(response.body).not_to include("password_digest")
    expect(response.body).not_to include("verifier_token")
  end

  it "returns 404 for a missing user" do
    get "/admin/users/#{User.maximum(:id).to_i + 1}", headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
