# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PurgeUserAssociatedData do
  include HomeNoticeSelectSpecHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "home notices" do
    before do
      campaign_row(user:, key: "test.picks", period_key: "week-1")
      delivery_row(user:, key: "test.class_canceled", identity: "class-1")
      campaign_row(user: other_user, key: "test.picks", period_key: "week-1")
    end

    it "removes only the purged user's rows", :aggregate_failures do
      described_class.call(user:)

      expect(CommandTower::HomeNotice.where(user_id: user.id)).to be_empty
      expect(CommandTower::HomeNotice.where(user_id: other_user.id).count).to eq(1)
    end

    it "leaves audit events untouched" do
      create_audit_event!(action: "home_notice_acknowledged")

      expect { described_class.call(user:) }
        .not_to(change { CommandTower::Audit::Event.where(action: "home_notice_acknowledged").count })
    end
  end
end
