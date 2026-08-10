# frozen_string_literal: true

RSpec.describe "Me phone verification", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"], phone_number: "+14155552671", phone_number_validated: false) }
  let(:headers) { authenticate_request_with_bearer!(user) }

  before do
    allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(true)
    CommandTower::Identity::PhoneVerification::SmsTransport.reset_adapter!
    CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter.reset!
    allow(CommandTower.config.identity.phone_verification).to receive(:sms_adapter).and_return("fake")
    allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(0.seconds)
  end

  context "when sending a verification code" do
    subject(:data) { response.parsed_body["data"] }

    before { post "/me/phone/verification", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns metadata without leaking the OTP" do
      expect(data.keys).to include("codeLength", "expiresAt", "resendAvailableAt", "phoneNumber")
      expect(data.values.join).not_to match(/\b\d{6}\b/)
      expect(CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter.deliveries).not_to be_empty
    end
  end

  context "when verifying a valid code" do
    let(:code) do
      post "/me/phone/verification", headers: headers
      CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter.deliveries.last[:body][/\d{6}/]
    end

    before { post "/me/phone/verification/verify", headers: headers, params: { code: }, as: :json }

    it { expect(response).to have_http_status(:ok) }

    it "marks the phone validated" do
      expect(response.parsed_body.dig("data", "phoneNumberValidated")).to eq(true)
      expect(user.reload.phone_number_validated).to eq(true)
    end
  end

  context "when verifying a blank code" do
    before { post "/me/phone/verification/verify", headers: headers, params: { code: "" }, as: :json }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns phone_verification_code_invalid" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("phone_verification_code_invalid")
    end
  end

  context "when SMS product gate is off" do
    before do
      allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(false)
      post "/me/phone/verification", headers: headers
    end

    it { expect(response).to have_http_status(:service_unavailable) }
  end
end
