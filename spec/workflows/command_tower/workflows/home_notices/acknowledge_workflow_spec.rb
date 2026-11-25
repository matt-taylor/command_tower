# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::HomeNotices::AcknowledgeWorkflow, :aggregate_failures do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user) }
  let(:impersonating) { false }
  let(:public_id) { row.public_id }
  let(:row) { campaign_row(user:, key: "test.terms", period_key: "") }
  let(:run) { -> { described_class.call(user:, impersonating:, notice_id: notice_id_for(public_id)) } }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    CommandTower::HomeNotices::Catalog.load!([campaign("test.terms", kind: :blocking)])
  end

  context "with the user's own notice" do
    before { row }

    it "acknowledges it and audits once" do
      expect(run.call.payload).to eq(recorded: true)
      expect(row.reload.acknowledged_at).to be_present
      expect(acknowledgement_audits.count).to eq(1)
    end

    it "is an idempotent success the second time" do
      run.call
      expect(run.call).to be_success
      expect(acknowledgement_audits.count).to eq(1)
    end
  end

  context "when impersonating" do
    let(:impersonating) { true }

    before { row }

    it "is forbidden and writes nothing" do
      expect(run.call.http_status).to eq(:forbidden)
      expect(row.reload.acknowledged_at).to be_nil
    end
  end

  context "when impersonation is unknown" do
    let(:impersonating) { nil }

    it("is forbidden") { expect(run.call.http_status).to eq(:forbidden) }
  end

  context "with another user's notice" do
    let(:public_id) { campaign_row(user: create(:user), key: "test.terms", period_key: "").public_id }

    it "is not found" do
      expect(run.call.http_status).to eq(:not_found)
      expect(acknowledgement_audits.count).to eq(0)
    end
  end

  context "when the database fails while acknowledging" do
    before do
      row
      allow(CommandTower::Services::HomeNotices::Acknowledge).to receive(:call).and_raise(ActiveRecord::StatementInvalid)
    end

    it("is unavailable (503)") { expect(run.call.http_status).to eq(:service_unavailable) }
  end
end
