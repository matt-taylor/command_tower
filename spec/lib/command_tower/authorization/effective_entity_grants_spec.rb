# frozen_string_literal: true

RSpec.describe CommandTower::Authorization::EffectiveEntityGrants, :with_rbac_setup do
  describe ".for_user" do
    context "when the user has allow_everything" do
      let(:user) { create(:user, :role_owner) }

      subject(:grants) { described_class.for_user(user) }

      it { expect(grants).to eq(described_class::ALL) }
    end

    context "when the user has composed host roles" do
      let(:user) { create(:user, :role_rbac_admin) }

      subject(:grants) { described_class.for_user(user) }

      it { expect(grants).to include("admin_rbac_assignments", "admin_users", "admin_workspace") }

      it { expect(grants).not_to include("admin_users_update") }
    end
  end

  describe ".subset?" do
    let(:actor) { create(:user, :role_rbac_admin) }
    let(:actor_grants) { described_class.for_user(actor) }

    context "when candidate grants are contained" do
      subject(:result) { described_class.subset?(described_class.for_role("support_admin"), actor_grants) }

      it { expect(result).to eq(true) }
    end

    context "when candidate grants include an extra entity" do
      subject(:result) { described_class.subset?(described_class.for_role("admin"), actor_grants) }

      it { expect(result).to eq(false) }
    end

    context "when the actor has allow_everything" do
      let(:actor) { create(:user, :role_owner) }

      subject(:result) { described_class.subset?(described_class.for_role("admin"), actor_grants) }

      it { expect(result).to eq(true) }
    end
  end
end
