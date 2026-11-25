# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::HomeNotices::UpdateControlWorkflow, :aggregate_failures do
  include HomeNoticeSelectSpecHelpers

  let(:admin) { create(:user, :role_admin) }
  let(:key) { "test.picks" }
  let(:audits) { CommandTower::Audit::Event.where(action: "home_notice_control_changed") }
  let(:run) do
    lambda do |enabled:, key: "test.picks"|
      CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
        described_class.call(user: admin, key:, enabled:)
      end
    end
  end

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before { CommandTower::HomeNotices::Catalog.load!([campaign("test.picks")]) }

  context "when disabling a registered key" do
    let!(:result) { run.call(enabled: false) }

    it "succeeds and stores the switch" do
      expect(result).to be_success
      expect(result.payload).to eq(key:, enabled: false)
      expect(CommandTower::HomeNoticeControl.find(key).enabled).to be(false)
    end

    it "audits the change as an admin action without an affected user" do
      expect(audits.sole).to have_attributes(
        attribution_mode: "admin_direct", actor_user_id: admin.id, affected_user_id: nil,
        metadata: { "key" => key }, change_set: { "enabled" => { "from" => true, "to" => false } }
      )
    end

    it "is an idempotent success without a second audit" do
      expect(run.call(enabled: false)).to be_success
      expect(audits.count).to eq(1)
    end

    it "audits the re-enable" do
      run.call(enabled: true)
      expect(CommandTower::HomeNoticeControl.find(key).enabled).to be(true)
      expect(audits.count).to eq(2)
    end
  end

  it "does not audit enabling a key that has no row" do
    expect(run.call(enabled: true)).to be_success
    expect(audits.count).to eq(0)
  end

  context "with an unregistered key" do
    let!(:result) { run.call(enabled: false, key: "test.unknown") }

    it "is a 404 and writes nothing" do
      expect(result.http_status).to eq(:not_found)
      expect(CommandTower::HomeNoticeControl.count).to eq(0)
      expect(audits.count).to eq(0)
    end
  end

  context "when the database fails" do
    before do
      allow(CommandTower::HomeNoticeControl).to receive(:lock).and_raise(ActiveRecord::StatementInvalid, "boom")
    end

    it "is a 503 and audits nothing" do
      expect(run.call(enabled: false).http_status).to eq(:service_unavailable)
      expect(audits.count).to eq(0)
    end
  end
end
