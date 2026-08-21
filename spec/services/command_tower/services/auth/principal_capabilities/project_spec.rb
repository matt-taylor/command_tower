# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PrincipalCapabilities::Project, :with_rbac_setup do
  subject(:result) { described_class.call(user:) }

  context "when the user is a member" do
    let(:user) { create(:user, roles: ["member"]) }

    it "returns me_audit_events when the host grants that entity" do
      expect(result).to be_success
      expect(result.data[:principal_capability_ids]).to eq(%w[me_audit_events])
    end
  end

  context "when the user is an audit operator" do
    let(:user) { create(:user, roles: ["audit_operator"]) }

    it "returns only granted Admin projectables" do
      expect(result).to be_success
      expect(result.data[:principal_capability_ids]).to eq(%w[admin_audit_events admin_workspace])
    end
  end

  context "when the user is an owner" do
    let(:user) { create(:user, :role_owner) }

    it "returns every registered projectable via allow_everything" do
      expect(result).to be_success
      expect(result.data[:principal_capability_ids]).to include(
        "admin_workspace",
        "admin_audit_events",
        "admin_messaging_announcements",
        "admin_users",
        "admin_users_update",
        "admin_rbac_assignments",
        "admin_impersonation",
        "me_audit_events",
        "dummy_admin_example"
      )
    end
  end
end
