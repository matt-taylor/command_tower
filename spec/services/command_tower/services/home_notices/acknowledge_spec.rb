# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Acknowledge do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user) }

  describe "an existing dismissible campaign row" do
    let(:picks) { campaign("test.picks") }
    let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48", impression_count: 1) }
    let!(:result) { acknowledge_notice(user:, notice_class: picks, row:) }

    it "acknowledges it", :aggregate_failures do
      expect(result.data).to include(acknowledged: true, recorded: true, public_id: row.public_id)
      expect(row.reload).to have_attributes(acknowledged_at: start_time, acknowledged_content_hash: nil)
    end

    it "audits it for the user with ids only", :aggregate_failures do
      expect(acknowledgement_audits.sole).to have_attributes(
        affected_user_id: user.id, retention: "one_year", user_history: true,
        metadata: { "notice_id" => row.public_id, "key" => "test.picks", "kind" => "campaign",
                    "severity" => "dismissible" }
      )
    end

    it "is an idempotent success the second time, with no second audit", :aggregate_failures do
      expect(acknowledge_notice(user:, notice_class: picks, row:, at: start_time + 1.hour).data)
        .to include(acknowledged: true, recorded: false, public_id: row.public_id)
      expect(row.reload.acknowledged_at).to eq(start_time)
      expect(acknowledgement_audits.count).to eq(1)
    end
  end

  describe "a blocking notice" do
    let!(:row) { campaign_row(user:, key: "test.terms", period_key: "week-48", first_shown_at: start_time) }

    before { acknowledge_notice(user:, notice_class: campaign("test.terms", kind: :blocking), row:) }

    it "stores the content hash on the row only", :aggregate_failures do
      expect(row.reload.acknowledged_content_hash).to match(/\A\h{64}\z/)
      expect(acknowledgement_audits.sole.metadata.keys).to contain_exactly("notice_id", "key", "kind", "severity")
      expect(acknowledgement_audits.sole.to_json).not_to include(row.acknowledged_content_hash)
    end
  end

  describe "a blocking notice that cannot be composed" do
    let!(:row) { campaign_row(user:, key: "test.terms", period_key: "week-48") }
    let(:broken) { campaign("test.terms", kind: :blocking, body: ->(_builder) { raise "boom" }) }

    it "still acknowledges, with no hash", :aggregate_failures do
      expect(acknowledge_notice(user:, notice_class: broken, row:)).to be_success
      expect(row.reload).to have_attributes(acknowledged_at: start_time, acknowledged_content_hash: nil)
    end
  end

  describe "a notice whose show? is false or raises" do
    let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

    [-> { false }, -> { raise "show? failed" }].each_with_index do |shows, index|
      context "with case #{index}" do
        let(:klass) { campaign("test.picks", shows: ->(**) { shows.call }) }

        it "acknowledges it anyway", :aggregate_failures do
          expect(acknowledge_notice(user:, notice_class: klass, row:).data).to include(recorded: true)
          expect(row.reload.acknowledged_at).to eq(start_time)
        end
      end
    end
  end

  describe "a campaign with no row in the period" do
    let(:row) { campaign_rows("test.terms").sole }

    before { acknowledge_notice(user:, notice_class: campaign("test.terms", kind: :blocking)) }

    it "creates the row already acknowledged, with the hash and an audit", :aggregate_failures do
      expect(row).to have_attributes(
        kind: "campaign", period_key: "week-48", acknowledged_at: start_time, impression_count: 0
      )
      expect(row.acknowledged_content_hash).to match(/\A\h{64}\z/)
      expect(acknowledgement_audits.count).to eq(1)
    end
  end

  describe "an existing delivery row" do
    let!(:row) { delivery_row(user:, key: "test.class_canceled", identity: "class/1") }

    it "acknowledges it and audits it as a delivery", :aggregate_failures do
      acknowledge_notice(user:, notice_class: delivery("test.class_canceled", kind: :blocking), row:)
      expect(row.reload.acknowledged_at).to eq(start_time)
      expect(acknowledgement_audits.sole.metadata).to include("kind" => "delivery", "severity" => "blocking")
    end
  end

  describe "a delivery without a row" do
    it "fails with not found" do
      expect(acknowledge_notice(user:, notice_class: delivery("test.class_canceled")).errors.first)
        .to be_a(CommandTower::Errors::NotFoundError)
    end
  end

  [true, nil].each do |flag|
    context "when impersonating is #{flag.inspect}" do
      let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

      it "fails with forbidden and writes nothing", :aggregate_failures do
        expect(acknowledge_notice(user:, notice_class: campaign("test.picks"), row:, impersonating: flag).errors.first)
          .to be_a(CommandTower::Errors::ForbiddenError)
        expect(row.reload.acknowledged_at).to be_nil
        expect(acknowledgement_audits.count).to eq(0)
      end
    end
  end

  context "when the audit cannot be written" do
    before { allow(CommandTower::Audit::Emit).to receive(:call).and_raise(ActiveRecord::StatementInvalid) }

    let(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

    it "rolls an update back with the transaction", :aggregate_failures do
      expect { acknowledge_notice(user:, notice_class: campaign("test.picks"), row:) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(row.reload.acknowledged_at).to be_nil
    end

    it "rolls a new campaign row back with the transaction", :aggregate_failures do
      expect { acknowledge_notice(user:, notice_class: campaign("test.picks")) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(campaign_rows("test.picks").count).to eq(0)
    end
  end

  describe "two concurrent acknowledgements" do
    self.use_transactional_tests = false

    around { |example| with_concurrent_pool { example.run } }

    context "with an existing row" do
      let(:row) { campaign_row(user:, key: "test.terms", period_key: "week-48") }
      let(:flags) do
        args = { user:, notice_class: campaign("test.terms", kind: :blocking), row: }
        concurrently { acknowledge_notice(**args).data[:recorded] }
      end

      it "acknowledges and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(row.reload.acknowledged_at).to eq(start_time)
        expect(acknowledgement_audits.count).to eq(1)
      end
    end

    context "with no row yet" do
      let(:flags) do
        args = { user:, notice_class: campaign("test.terms", kind: :blocking) }
        concurrently { acknowledge_notice(**args).data[:recorded] }
      end

      it "creates one row and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(campaign_rows("test.terms").sole.acknowledged_at).to eq(start_time)
        expect(acknowledgement_audits.count).to eq(1)
      end
    end
  end
end
