# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Users::ReplaceUserRoles, :with_rbac_setup do
  describe ".call" do
    let(:user) { create(:user, roles: %w[member owner]) }
    let(:desired_roles) { %w[member support_admin] }

    subject(:result) { described_class.call(user:, desired_roles:) }

    context "when assignable roles change" do
      it { expect(result).to be_success }

      it "preserves non-assignable owner and applies desired assignable roles" do
        expect(result.data[:user].roles).to contain_exactly("member", "owner", "support_admin")
        expect(result.data[:assigned_roles]).to eq(%w[support_admin])
        expect(result.data[:revoked_roles]).to eq([])
        expect(result.data[:changed]).to eq(true)
      end
    end

    context "when an assignable role is revoked" do
      let(:user) { create(:user, roles: %w[member support_admin]) }
      let(:desired_roles) { %w[member] }

      it { expect(result.data[:revoked_roles]).to eq(%w[support_admin]) }

      it { expect(result.data[:user].roles).to eq(%w[member]) }
    end

    context "when the assignable set is unchanged" do
      let(:desired_roles) { %w[member] }

      it { expect(result.data[:changed]).to eq(false) }

      it { expect(result.data[:user].roles).to contain_exactly("member", "owner") }
    end
  end
end
