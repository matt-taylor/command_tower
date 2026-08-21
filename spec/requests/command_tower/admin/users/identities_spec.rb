# frozen_string_literal: true

RSpec.describe "PATCH /admin/users/:id identity mutations", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member) { create(:user, roles: ["member"], first_name: "Jane", last_name: "Member") }
  let(:headers) { authenticate_request_with_bearer!(admin) }
  let(:user_keys) do
    %w[
      id firstName lastName fullName username email emailValidated
      phoneNumber phoneNumberValidated roles createdAt
    ]
  end

  describe "PATCH /admin/users/:id/name" do
    let(:params) { { firstName: "Ada", lastName: "Lovelace" } }

    context "without authentication" do
      before { patch "/admin/users/#{member.id}/name", params: params, as: :json }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context "when the principal can read users but not update" do
      let(:operator) { create(:user, :role_impersonation_operator) }
      let(:headers) { authenticate_request_with_bearer!(operator) }

      before { patch "/admin/users/#{member.id}/name", params: params, headers: headers, as: :json }

      it { expect(response).to have_http_status(:forbidden) }
    end

    context "when the update is valid" do
      before { patch "/admin/users/#{member.id}/name", params: params, headers: headers, as: :json }

      subject(:body) { response.parsed_body }

      it { expect(response).to have_http_status(:ok) }

      it "returns the Show user envelope" do
        expect(body.keys).to contain_exactly("data", "meta", "errors")
        expect(body.fetch("errors")).to eq([])
        expect(body.fetch("data").keys).to match_array(user_keys)
        expect(body.dig("data", "firstName")).to eq("Ada")
        expect(body.dig("data", "lastName")).to eq("Lovelace")
        expect(body.dig("data", "fullName")).to eq("Ada Lovelace")
        expect(response.body).not_to include("password_digest")
      end
    end

    context "when required fields are missing" do
      before do
        patch "/admin/users/#{member.id}/name", params: { firstName: "" }, headers: headers, as: :json
      end

      subject(:body) { response.parsed_body }

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it "returns a validation envelope" do
        expect(body.fetch("data")).to be_nil
        expect(body.dig("errors", 0, "code")).to eq("validation_failed")
      end
    end

    context "when the user is missing" do
      before do
        patch "/admin/users/#{User.maximum(:id).to_i + 1}/name", params: params, headers: headers, as: :json
      end

      it { expect(response).to have_http_status(:not_found) }

      it { expect(response.parsed_body.fetch("data")).to be_nil }
    end
  end

  describe "PATCH /admin/users/:id/username" do
    context "when the update is valid" do
      before do
        patch "/admin/users/#{member.id}/username",
          params: { username: "ada_lovelace" },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns the updated username" do
        expect(response.parsed_body.dig("data", "username")).to eq("ada_lovelace")
        expect(response.parsed_body.fetch("data").keys).to match_array(user_keys)
      end
    end
  end

  describe "PATCH /admin/users/:id/email" do
    context "when the update is valid" do
      before do
        patch "/admin/users/#{member.id}/email",
          params: { email: "ada@example.com" },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns the updated email and unverified flag" do
        expect(response.parsed_body.dig("data", "email")).to eq("ada@example.com")
        expect(response.parsed_body.dig("data", "emailValidated")).to eq(false)
        expect(response.parsed_body.fetch("data").keys).to match_array(user_keys)
      end
    end
  end

  describe "PATCH /admin/users/:id/email-validation" do
    context "when setting validation independently" do
      let(:member) { create(:user, :unvalidated_email, roles: ["member"]) }

      before do
        patch "/admin/users/#{member.id}/email-validation",
          params: { emailValidated: true },
          headers: headers,
          as: :json
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns verified without changing the email" do
        expect(response.parsed_body.dig("data", "emailValidated")).to eq(true)
        expect(response.parsed_body.dig("data", "email")).to eq(member.email)
      end
    end
  end
end
