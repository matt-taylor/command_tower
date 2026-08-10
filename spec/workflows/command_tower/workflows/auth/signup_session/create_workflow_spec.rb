# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::SignupSession::CreateWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(client_ip: client_ip) }

    let(:client_ip) { "203.0.113.20" }

    before { flush_signup_rate_limits! }

    it "returns a signup session token and expiration" do
      expect(result).to be_success
      expect(result.http_status).to eq(:created)
      expect(result.payload[:signupSessionToken]).to be_present
      expect(result.payload[:expiresAt]).to be_present
    end

    context "when the client ip is rate limited" do
      before do
        allow(CommandTower::Services::Auth::SignupRateLimits::CheckTokenIssue).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::Auth::SignupIpRateLimitError.new]
          )
        )
      end

      it "returns too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupIpRateLimitError)
        )
      end
    end

    context "when session creation fails" do
      before do
        allow(CommandTower::Services::Auth::SignupSession::Create).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        )
      end

      it "returns internal_server_error" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:internal_server_error)
      end
    end
  end
end
