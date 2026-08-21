# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Users::UpdateRolesWorkflow, :with_rbac_setup do
  describe ".call" do
    let(:actor) { create(:user, :role_rbac_admin) }
    let(:member) { create(:user, roles: ["member"]) }

    context "when the update succeeds" do
      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: actor.id, effective_user_id: actor.id) do
          described_class.call(id: member.id, user: actor, roles: %w[member support_admin])
        end
      end

      it { expect(result).to be_success }

      it "serializes the Show user payload" do
        expect(result.payload.fetch(:roles)).to contain_exactly("member", "support_admin")
        expect(result.payload).not_to have_key(:passwordDigest)
      end
    end

    context "when a role is assigned" do
      before do
        CommandTower.with_execution(source: :http, user_id: actor.id, effective_user_id: actor.id) do
          described_class.call(id: member.id, user: actor, roles: %w[member support_admin])
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "role_assigned") }

      it "persists admin_direct role_assigned" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.affected_user_id).to eq(member.id)
      end
    end

    context "when a role is revoked" do
      before do
        member.update!(roles: %w[member support_admin])
        CommandTower.with_execution(source: :http, user_id: actor.id, effective_user_id: actor.id) do
          described_class.call(id: member.id, user: actor, roles: %w[member])
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "role_revoked") }

      it "persists admin_direct role_revoked against the target" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.actor_user_id).to eq(actor.id)
        expect(row.affected_user_id).to eq(member.id)
        expect(row.change_set).to eq("role" => { "from" => "support_admin", "to" => nil })
      end
    end

    context "when the user is missing" do
      subject(:result) { described_class.call(id: 0, user: actor, roles: %w[member]) }

      it { expect(result).to be_failure }

      it { expect(result.http_status).to eq(:not_found) }
    end
  end
end
