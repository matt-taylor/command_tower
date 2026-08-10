# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::AuthorizeRequestWorkflow, :with_rbac_setup do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: current_user,
        controller_class: CommandTower::Auth::EmailVerification::SendController,
        action_name: "create"
      )
    end

    context "with a role the host mapped onto the action" do
      let(:current_user) { create(:user, roles: ["member"]) }

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:ok) }
      it { expect(result.payload).to eq({}) }
    end

    context "without the required role" do
      let(:current_user) { create(:user, roles: []) }

      it "fails with forbidden" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:forbidden)
        expect(result.errors.first).to be_a(CommandTower::Errors::ForbiddenError)
      end
    end
  end
end
