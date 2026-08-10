# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::SignupSession::AuthenticateWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(request: request) }

    let(:signup_token) { CommandTower::Services::Auth::SignupSession::Create.call.data[:token] }

    context "without a signup session token" do
      let(:request) { build_signup_request }

      it "returns SignupSessionMissingError" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionMissingError)
        )
      end
    end

    context "with a malformed authorization scheme" do
      let(:request) { build_signup_request(authorization: "Bearer sometoken") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionInvalidError)
        )
      end
    end

    context "with an unparseable token" do
      let(:request) { build_signup_request(authorization: "Signup invalid-token") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionInvalidError)
      end
    end

    context "with a valid token" do
      let(:request) { build_signup_request(authorization: "Signup #{signup_token}") }

      it "returns the signup session" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:signup_session]).to be_a(CommandTower::Auth::SignupSessionContext)
        expect(result.payload[:signup_session].jti).to be_present
      end
    end
  end
end
