# frozen_string_literal: true

RSpec.describe CommandTower::SharedSequences::Admin::Users::ResolveScopedUser do
  describe ".call" do
    subject(:result) { described_class.call(id:, principal: admin, scope_value:) }

    let(:admin) { create(:user, :role_admin) }
    let(:member) { create(:user, roles: ["member"]) }
    let(:id) { member.id }
    let(:scope_value) { nil }

    context "when the user exists" do
      it { expect(result).to be_a(described_class::Result) }

      it { expect(result.user.id).to eq(member.id) }
    end

    context "when the user is missing" do
      let(:id) { 0 }

      it { expect(result).to be_a(CommandTower::Workflows::WorkflowResult) }

      it { expect(result.http_status).to eq(:not_found) }
    end
  end
end
