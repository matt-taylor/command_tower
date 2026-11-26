# frozen_string_literal: true

RSpec.describe "PATCH /me/username", :with_rbac_setup, type: :request do
  subject(:make_request) { patch "/me/username", params: params, headers: headers, as: :json }

  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:params) { { username: "new_name" } }
  let(:user) { create(:user, roles: ["member"], username: nil) }
  let(:username_config) { { self_service: true, self_change: false } }

  before do
    allow(CommandTower.config.username).to receive_messages(username_config)
  end

  context "without authentication" do
    let(:headers) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "when the user has no username" do
    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "persists the username" do
      expect(user.reload.username).to eq("new_name")
    end

    it "returns the account with the username" do
      expect(response.parsed_body["data"]).to include("username" => "new_name")
    end
  end

  context "when the username is set" do
    it "records username_set in the audit ledger" do
      expect { make_request }.to change { CommandTower::Audit::Event.where(action: "username_set").count }.by(1)
    end
  end

  context "when self_service is off" do
    let(:username_config) { { self_service: false, self_change: false } }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }

    it "returns username_change_not_allowed" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("username_change_not_allowed")
    end
  end

  context "when the user already has a username and self_change is off" do
    let(:user) { create(:user, roles: ["member"], username: "existing_name") }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }

    it "keeps the username" do
      expect(user.reload.username).to eq("existing_name")
    end
  end

  context "when the user already has a username and self_change is on" do
    let(:user) { create(:user, roles: ["member"], username: "existing_name") }
    let(:username_config) { { self_service: true, self_change: true } }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "changes the username" do
      expect(user.reload.username).to eq("new_name")
    end
  end

  context "when another active user has the name in a different case" do
    before do
      create(:user, username: "NEW_NAME")
      make_request
    end

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns username_taken" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("username_taken")
    end
  end

  context "when the username contains an @" do
    let(:params) { { username: "person@example.com" } }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "does not persist it" do
      expect(user.reload.username).to be_nil
    end
  end

  context "when the username fails the shape rules" do
    let(:params) { { username: "ab" } }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "when the username is missing" do
    let(:params) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "when the unique index rejects a concurrent write" do
    before do
      headers
      allow(CommandTower::UserAttributes::Mutate).to receive(:call).and_raise(ActiveRecord::RecordNotUnique)
      make_request
    end

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns username_taken" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("username_taken")
    end
  end

  context "when the per-user hourly limit is exceeded" do
    before do
      allow(CommandTower::Services::RateLimits::Check).to receive(:call)
        .and_return(Struct.new(:data) { def failure? = false }.new({ count: 11, ttl: 120 }))
      make_request
    end

    it { expect(response).to have_http_status(:too_many_requests) }
  end

  context "with an unverified email past a grace period of 0" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"], username: nil) }
    let(:requirement) do
      CommandTower::LoginStrategy::PlainText::EmailVerification::Required::Requirement.new(
        required: true, required_after_time: 1.minute.ago
      )
    end

    before do
      CommandTower.configure { |config| config.login.plain_text.email_verify.enable = true }
      allow(CommandTower::LoginStrategy::PlainText::EmailVerification::Required)
        .to receive(:call).and_return(requirement)
    end

    it "still sets the username (412-exempt)" do
      make_request
      expect(response).to have_http_status(:ok)
    end

    it "keeps the gate on other self-service routes" do
      patch "/me/name", params: { firstName: "A", lastName: "B" }, headers: headers, as: :json
      expect(response).to have_http_status(:precondition_failed)
    end
  end
end
