# frozen_string_literal: true

RSpec.describe "PATCH /me/name", :with_rbac_setup, type: :request do
  subject(:make_request) { patch path, params: params, headers: headers, as: :json }

  let(:path) { "/me/name" }
  let(:headers) { {} }
  let(:params) { { firstName: "Grace", lastName: "Hopper" } }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid update" do
    let(:user) { create(:user, roles: ["member"], first_name: "Old", last_name: "Name") }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns the updated account" do
      expect(response.parsed_body["data"]).to include("firstName" => "Grace", "lastName" => "Hopper", "fullName" => "Grace Hopper")
    end

    it "persists the change" do
      expect(user.reload).to have_attributes(first_name: "Grace", last_name: "Hopper")
    end
  end

  context "with missing fields" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) { { firstName: "" } }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end
end
