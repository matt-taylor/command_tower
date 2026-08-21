# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Impersonation::StartWorkflow, :with_rbac_setup do
  describe ".call" do
    subject(:result) { described_class.call(id: target.id, actor:) }

    let(:actor) { create(:user, :role_impersonation_operator) }
    let(:target) { create(:user, roles: ["member"]) }

    before do
      CommandTower::Current.user_id = actor.id
      CommandTower::Current.effective_user_id = actor.id
    end

    after { CommandTower::Current.reset }

    it "creates a session and issues an overlay token" do
      expect(result).to be_success
      expect(result.http_status).to eq(:created)
      expect(result.payload[:id]).to be_present
      expect(result.payload[:actorUserId]).to eq(actor.id)
      expect(result.payload[:targetUserId]).to eq(target.id)
      expect(result.response_effects[:set_token][:token]).to be_present
    end

    context "when inspecting impersonation_started" do
      before { result }

      let(:row) { CommandTower::Audit::Event.find_by!(action: "impersonation_started") }

      it "emits impersonation_started as admin_direct" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.actor_user_id).to eq(actor.id)
        expect(row.affected_user_id).to eq(target.id)
      end
    end

    context "when nested impersonation is active" do
      before { CommandTower::Current.impersonation_active = true }

      it "rejects nested impersonation" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:forbidden)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::NestedImpersonationError)
      end
    end

    context "when the actor targets themselves" do
      subject(:result) { described_class.call(id: actor.id, actor:) }

      it "rejects self impersonation" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
      end
    end
  end
end
