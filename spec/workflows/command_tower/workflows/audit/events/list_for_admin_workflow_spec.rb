# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Audit::Events::ListForAdminWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(limit: 50, offset: 0, user: admin) }

    let(:admin) { create(:user) }

    before do
      create_audit_event!(
        action: "session_created",
        affected_user_id: 9,
        user_history: false
      )
    end

    it { expect(result).to be_success }

    it "includes rows that are not user-history eligible" do
      expect(result.payload.map { |item| item[:eventName] }).to include("session_created")
    end
  end
end
