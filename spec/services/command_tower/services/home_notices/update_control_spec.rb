# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::UpdateControl, :aggregate_failures do
  let(:admin) { create(:user, :role_admin) }
  let(:key) { "test.picks" }
  let(:enabled) { false }
  let(:result) { described_class.call(key:, enabled:, updated_by_user_id: admin.id) }
  let(:control) { CommandTower::HomeNoticeControl.find(key) }

  context "with no control row" do
    before { result }

    it "creates a disabled row and reports a change" do
      expect(result.data).to include(key:, enabled: false, previous_enabled: true, changed: true)
      expect(control).to have_attributes(enabled: false, updated_by_user_id: admin.id)
    end

    context "when enabling" do
      let(:enabled) { true }

      it "reports no change" do
        expect(result.data[:changed]).to be(false)
        expect(control.enabled).to be(true)
      end
    end
  end

  context "with a disabled row" do
    before { CommandTower::HomeNoticeControl.create!(key:, enabled: false) }

    context "when enabling" do
      let(:enabled) { true }

      it "re-enables it and reports a change" do
        expect(result.data).to include(previous_enabled: false, changed: true)
        expect(control).to have_attributes(enabled: true, updated_by_user_id: admin.id)
      end
    end

    it "is idempotent when already disabled" do
      expect(result).to be_success
      expect(result.data[:changed]).to be(false)
    end
  end

  context "with another key's row" do
    before do
      CommandTower::HomeNoticeControl.create!(key: "test.other", enabled: false)
      result
    end

    it "leaves it alone" do
      expect(CommandTower::HomeNoticeControl.find("test.other").enabled).to be(false)
      expect(CommandTower::HomeNoticeControl.count).to eq(2)
    end
  end

  context "when the database fails" do
    before do
      allow(CommandTower::HomeNoticeControl).to receive(:lock).and_raise(ActiveRecord::StatementInvalid, "boom")
    end

    it "fails with an internal error" do
      expect(result).to be_failure
      expect(result.errors.first).to be_a(CommandTower::Errors::InternalError)
    end
  end
end
