# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Users::RoleAssignmentPolicy, :with_rbac_setup do
  describe ".call" do
    let(:actor) { create(:user, :role_rbac_admin) }
    let(:target) { create(:user, roles: ["member"]) }
    let(:desired_roles) { %w[member support_admin] }

    subject(:result) { described_class.call(actor:, target:, desired_roles:) }

    context "when the candidate is a differently named subset role" do
      it { expect(result).to be_success }
    end

    context "when the actor does not hold the candidate role by name" do
      it { expect(actor.roles).not_to include("support_admin") }

      it { expect(result).to be_success }
    end

    context "when the candidate grants an extra entity" do
      let(:desired_roles) { %w[member admin] }

      it { expect(result).to be_failure }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::ForbiddenError) }
    end

    context "when the actor has allow_everything" do
      let(:actor) { create(:user, :role_owner) }
      let(:desired_roles) { %w[member messaging_operator] }

      it { expect(result).to be_success }
    end

    context "when allow_everything tries to assign owner" do
      let(:actor) { create(:user, :role_owner) }
      let(:desired_roles) { %w[member owner] }

      it { expect(result).to be_failure }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::ForbiddenError) }
    end

    context "when the desired name is unknown" do
      let(:desired_roles) { %w[member not_a_role] }

      it { expect(result).to be_failure }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError) }
    end

    context "when self-assignment would drop admin_rbac_assignments" do
      let(:target) { actor }
      let(:desired_roles) { %w[member] }

      it { expect(result).to be_failure }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::ForbiddenError) }
    end
  end
end
