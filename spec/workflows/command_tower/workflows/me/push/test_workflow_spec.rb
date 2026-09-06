# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Push::TestWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(current_user: user, auth_context:)
    end

    let(:user) { create(:user, roles: ["member"]) }
    let(:auth_context) do
      CommandTower::Auth::AuthContext.new(
        user:,
        token_expires_at: 1.hour.from_now.iso8601,
        token_source: :header,
        roles: user.roles,
        principal_type: :user,
        generated_token: nil,
      )
    end

    before do
      allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(true)
    end

    context "when push product gate is off" do
      before do
        allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(false)
      end

      it "returns capability unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushCapabilityUnavailableError)
      end
    end

    context "when SendSelfTest succeeds" do
      before do
        allow(CommandTower::Services::Account::Push::SendSelfTest).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.success(
            data: {
              communication_id: 42,
              destination_plan_id: 7,
              selected_channels: ["push"],
              communication_status: "accepted",
            },
          ),
        )
      end

      it { expect(result).to be_success }

      it "returns safe Produce identifiers without tokens" do
        expect(result.payload).to eq(
          communicationId: 42,
          destinationPlanId: 7,
          selectedChannels: ["push"],
          status: "accepted",
        )
        expect(result.payload.to_json).not_to include("ExponentPushToken")
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end

    context "when rate limited" do
      before do
        allow(CommandTower::Services::Account::Push::SendSelfTest).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::Account::PushTestRateLimitError.new(retry_after_seconds: 30)],
          ),
        )
      end

      it "maps to too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors.first.code).to eq("push_test_rate_limited")
      end
    end

    context "when no endpoint is registered" do
      before do
        allow(CommandTower::Services::Account::Push::SendSelfTest).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::Account::PushTestNoEndpointError.new],
          ),
        )
      end

      it "maps to unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
      end
    end
  end
end
