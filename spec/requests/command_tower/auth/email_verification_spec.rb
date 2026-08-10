# frozen_string_literal: true

RSpec.describe "POST /auth/email-verification/send", :with_rbac_setup, type: :request do
  subject(:make_request) { post path, headers: headers, as: :json }

  let(:path) { "/auth/email-verification/send" }
  let(:headers) { {} }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with an unverified user" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before do
      allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_return(
        instance_double(Mail::Message, deliver: true)
      )
      make_request
    end

    it { expect(response).to have_http_status(:created) }

    it "returns a success message" do
      expect(response.parsed_body["data"]["message"]).to include("Successfully sent")
    end
  end

  context "when the user is already verified" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns idempotent success" do
      expect(response.parsed_body["data"]["message"]).to include("already verified")
    end
  end

  context "without a role the host mapped onto the action" do
    let(:user) { create(:user, :unvalidated_email, roles: []) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when email verification is disabled" do
    before do
      CommandTower.configure do |config|
        config.login.plain_text.email_verify.enable = false
      end
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.login.plain_text.email_verify.enable = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end

RSpec.describe "POST /auth/email-verification/verify", :with_rbac_setup, type: :request do
  subject(:make_request) { post path, params: params, headers: headers, as: :json }

  let(:path) { "/auth/email-verification/verify" }
  let(:params) { { code: "123456" } }
  let(:headers) { {} }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with an incorrect code" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns verification_code_invalid" do
      expect(response.parsed_body["errors"].first["code"]).to eq("verification_code_invalid")
    end
  end

  context "without a code" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "names the missing field" do
      expect(response.parsed_body["errors"].first["code"]).to eq("verification_code_invalid")
      expect(response.parsed_body["errors"].first["details"]).to eq("code" => "Verification code is required")
    end
  end

  context "with the correct code" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) do
      code = CommandTower::Secrets::Generate.call(
        user: user,
        secret_length: CommandTower.config.login.plain_text.email_verify.verify_code_length,
        reason: CommandTower::Secrets::EMAIL_VERIFICIATION,
        use_count_max: 1,
        death_time: 10.minutes,
        type: CommandTower::Secrets::NUMERIC,
        cleanse: true
      ).secret

      { code: code }
    end

    before { make_request }

    it { expect(response).to have_http_status(:created) }

    it "verifies the email" do
      expect(response.parsed_body["data"]["message"]).to eq("Successfully verified email")
      expect(user.reload.email_validated).to be(true)
    end
  end

  context "when the user is already verified" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns idempotent success" do
      expect(response.parsed_body["data"]["message"]).to include("already verified")
    end
  end

  context "when email verification is disabled" do
    before do
      CommandTower.configure do |config|
        config.login.plain_text.email_verify.enable = false
      end
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.login.plain_text.email_verify.enable = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end
