# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Audit::Events::ListForUserWorkflow do
  let(:user) { create(:user, roles: ["member"]) }

  describe ".call" do
    subject(:result) { described_class.call(user:, limit: 50, offset: 0) }

    let!(:row) do
      create_audit_event!(
        action: "phone_updated",
        affected_user_id: user.id,
        actor_user_id: user.id,
        change_set: { "phone" => { "from" => "+14155551212", "to" => nil } },
        sensitive_fields: ["phone"],
        user_history: true
      )
    end

    it { expect(result).to be_success }

    it "returns serialized masked events without querying in the workflow" do
      expect(result.payload.first).to include(id: row.id, eventName: "phone_updated")
      expect(result.payload.first.dig(:changes, "phone", "from")).to eq("*******1212")
      expect(result.meta).to include(limit: 50, offset: 0, totalCount: 1)
    end
  end
end
