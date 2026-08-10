# frozen_string_literal: true

RSpec.describe "Me phone", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }

  before do
    allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(true)
  end

  it "rejects unauthenticated update" do
    patch "/me/phone", params: { phoneNumber: "4155552671" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "updates and normalizes a phone number" do
    patch "/me/phone", headers: headers, params: { phoneNumber: "4155552671" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "phoneNumber")).to eq("+14155552671")
    expect(response.parsed_body.dig("data", "phoneNumberValidated")).to eq(false)
  end

  context "when clearing phone on delete" do
    before do
      user.update!(phone_number: "+14155552671", phone_number_validated: true)
      delete "/me/phone", headers: headers
    end

    it { expect(response).to have_http_status(:ok) }

    it "clears the phone number" do
      expect(response.parsed_body.dig("data", "phoneNumber")).to be_nil
      expect(user.reload.phone_number).to be_nil
    end
  end

  context "when SMS product gate is off" do
    before do
      allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(false)
    end

    it "returns service unavailable when SMS product gate is off" do
      patch "/me/phone", headers: headers, params: { phoneNumber: "4155552671" }, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("sms_capability_unavailable")
    end

    it "does not apply Engine SMS route constraints" do
      expect(CommandTower::Engine.routes.recognize_path("/me/phone", method: :patch)).to include(
        controller: "command_tower/me/phone",
        action: "update",
      )
    end
  end
end
