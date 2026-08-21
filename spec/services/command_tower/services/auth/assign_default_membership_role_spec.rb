# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::AssignDefaultMembershipRole do
  subject(:result) { described_class.call(user: user) }

  let(:user) { create(:user, roles: []) }

  before { CommandTower::Authorization.default_defined! }

  context "when default_membership_role is nil" do
    before do
      allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return(nil)
      result
    end

    it { expect(result).to be_success }

    it "does not change roles" do
      expect(user.reload.roles).to eq([])
    end
  end

  context "when default_membership_role is member" do
    before do
      allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return("member")
      result
    end

    it { expect(result).to be_success }

    it "assigns member" do
      expect(user.reload.roles).to eq(["member"])
    end
  end

  context "when the configured role is missing" do
    before do
      allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return("not_a_role")
      result
    end

    it { expect(result).to be_failure }

    it "returns DefaultMembershipAssignmentError" do
      expect(result.errors.first).to be_a(CommandTower::Errors::Auth::DefaultMembershipAssignmentError)
    end

    it "does not change roles" do
      expect(user.reload.roles).to eq([])
    end
  end
end
