# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::RecordImpression do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user) }
  let(:picks) { campaign("test.picks") }
  let(:class_canceled) { delivery("test.class_canceled", kind: :blocking) }

  # D11 asked the build to confirm whether the campaign upsert can report a created row. It cannot:
  # Rails connects mysql2 with FOUND_ROWS, so an insert and an unchanged duplicate both report one
  # affected row (and the adapter offers no RETURNING). RecordImpression therefore uses the D11
  # fallback, `insert!` plus RecordNotUnique, then the conditional UPDATE.
  describe "the created signal" do
    let(:connection) { CommandTower::HomeNotice.connection }
    let(:upsert_sql) do
      <<~SQL.squish
        INSERT INTO command_tower_home_notices
          (public_id, user_id, kind, `key`, campaign_key, period_key, impression_count, created_at, updated_at)
        VALUES
          ('probe', #{user.id}, 'campaign', 'test.picks', 'test.picks', '', 1,
           #{connection.quote(start_time)}, #{connection.quote(start_time)})
        ON DUPLICATE KEY UPDATE impression_count = impression_count
      SQL
    end

    it "cannot come from the upsert: an insert and an unchanged duplicate report the same row count" do
      expect(Array.new(2) { connection.exec_update(upsert_sql) }).to eq([1, 1])
    end
  end

  context "when a concurrent request already created the period's row" do
    let!(:existing) do
      campaign_row(
        user:, key: "test.picks", period_key: "week-48", impression_count: 1,
        first_shown_at: start_time, last_shown_at: start_time
      )
    end

    it "takes the RecordNotUnique path: not recorded inside 60 s and not audited", :aggregate_failures do
      expect(record_impression(user:, notice_class: picks).data).to include(
        recorded: false, first_impression: false, public_id: existing.public_id
      )
      expect(existing.reload.impression_count).to eq(1)
      expect(impression_audits.count).to eq(0)
    end

    it "counts a later impression on that row without auditing", :aggregate_failures do
      expect(record_impression(user:, notice_class: picks, at: start_time + 2.minutes).data).to include(
        recorded: true, first_impression: false
      )
      expect(existing.reload.impression_count).to eq(2)
      expect(impression_audits.count).to eq(0)
    end
  end

  describe "the first impression of a campaign period" do
    let!(:result) { record_impression(user:, notice_class: picks) }
    let(:row) { campaign_rows("test.picks").sole }

    it "creates the row with one impression", :aggregate_failures do
      expect(result.data).to include(recorded: true, first_impression: true, public_id: row.public_id)
      expect(row).to have_attributes(
        kind: "campaign", key: "test.picks", period_key: "week-48", impression_count: 1,
        first_shown_at: start_time, last_shown_at: start_time
      )
    end

    it "audits it with ids only" do
      expect(impression_audits.sole.metadata).to eq(
        "notice_id" => row.public_id, "key" => "test.picks", "kind" => "campaign", "severity" => "dismissible"
      )
    end

    it "audits it for the user, kept ninety days and out of the user's history" do
      expect(impression_audits.sole).to have_attributes(
        affected_user_id: user.id, retention: "ninety_days", user_history: false
      )
    end
  end

  context "when the audit cannot be written" do
    before { allow(CommandTower::Audit::Emit).to receive(:call).and_raise(ActiveRecord::StatementInvalid) }

    it "writes no row: the audit shares the transaction", :aggregate_failures do
      expect { record_impression(user:, notice_class: picks) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(campaign_rows("test.picks").count).to eq(0)
    end
  end

  describe "a later impression in the same period" do
    let(:row) { campaign_rows("test.picks").sole }

    before { record_impression(user:, notice_class: picks) }

    it "counts it without a second audit", :aggregate_failures do
      expect(record_impression(user:, notice_class: picks, row:, at: start_time + 2.minutes).data).to include(
        recorded: true, first_impression: false
      )
      expect(row.reload).to have_attributes(impression_count: 2, last_shown_at: start_time + 2.minutes)
      expect(impression_audits.count).to eq(1)
    end

    it "is idempotent within 60 s", :aggregate_failures do
      expect(record_impression(user:, notice_class: picks, row:, at: start_time + 59.seconds).data).to include(
        recorded: false, public_id: row.public_id
      )
      expect(row.reload).to have_attributes(impression_count: 1, last_shown_at: start_time)
      expect(impression_audits.count).to eq(1)
    end

    it "records again at 60 s" do
      expect(record_impression(user:, notice_class: picks, row:, at: start_time + 60.seconds).data[:recorded])
        .to be(true)
    end
  end

  describe "the first impression of a new period" do
    let(:later) { { period_key: "week-49", at: start_time + 2.minutes } }

    before { record_impression(user:, notice_class: picks) }

    it "creates a new row and audits it", :aggregate_failures do
      expect(record_impression(user:, notice_class: picks, **later).data).to include(first_impression: true)
      expect(campaign_rows("test.picks").order(:period_key).pluck(:period_key, :impression_count))
        .to eq([["week-48", 1], ["week-49", 1]])
      expect(impression_audits.count).to eq(2)
    end
  end

  describe "an existing delivery row never shown" do
    let(:row) { delivery_row(user:, key: "test.class_canceled", identity: "class/1") }
    let(:second) { record_impression(user:, notice_class: class_canceled, row:, at: start_time + 2.minutes) }

    it "sets first_shown_at and audits the delivery", :aggregate_failures do
      expect(record_impression(user:, notice_class: class_canceled, row:).data).to include(
        recorded: true, first_impression: true
      )
      expect(row.reload).to have_attributes(impression_count: 1, first_shown_at: start_time, last_shown_at: start_time)
      expect(impression_audits.sole.metadata).to include("kind" => "delivery", "severity" => "blocking")
    end

    it "audits only the first of two impressions", :aggregate_failures do
      record_impression(user:, notice_class: class_canceled, row:)
      expect(second.data[:first_impression]).to be(false)
      expect(row.reload.impression_count).to eq(2)
      expect(impression_audits.count).to eq(1)
    end
  end

  context "with a campaign row another mutation created" do
    let(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

    it "audits its first impression" do
      expect(record_impression(user:, notice_class: picks, row:).data)
        .to include(recorded: true, first_impression: true, public_id: row.public_id)
    end
  end

  describe "a delivery without a row" do
    it "fails with not found" do
      expect(record_impression(user:, notice_class: class_canceled).errors.first)
        .to be_a(CommandTower::Errors::NotFoundError)
    end
  end

  [true, nil].each do |flag|
    context "when impersonating is #{flag.inspect}" do
      it "writes nothing", :aggregate_failures do
        expect(record_impression(user:, notice_class: picks, impersonating: flag).data).to include(
          recorded: false, first_impression: false, public_id: nil
        )
        expect(CommandTower::HomeNotice.count).to eq(0)
        expect(impression_audits.count).to eq(0)
      end
    end
  end

  # Each `flags` let builds its inputs on the main thread before `concurrently` starts the threads.
  describe "two concurrent impressions" do
    self.use_transactional_tests = false

    around { |example| with_concurrent_pool { example.run } }

    context "with the first impression of a campaign period" do
      let(:flags) do
        args = { user:, notice_class: picks }
        concurrently { record_impression(**args).data[:recorded] }
      end

      it "creates one row, counts once inside 60 s and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(campaign_rows("test.picks").sole.impression_count).to eq(1)
        expect(impression_audits.count).to eq(1)
      end
    end

    context "with the first impression of a delivery" do
      let(:row) { delivery_row(user:, key: "test.class_canceled", identity: "class/1") }
      let(:flags) do
        args = { user:, notice_class: class_canceled, row: }
        concurrently { record_impression(**args).data[:recorded] }
      end

      it "counts once inside 60 s and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(row.reload).to have_attributes(impression_count: 1, first_shown_at: start_time)
        expect(impression_audits.count).to eq(1)
      end
    end

    # Without the idempotency window both impressions count, which isolates the audit decision:
    # the count is 2 and the audit is still written exactly once.
    context "with a campaign period and no idempotency window" do
      let(:flags) do
        args = { user:, notice_class: picks }
        concurrently { record_impression(**args).data[:first_impression] }
      end

      before { stub_const("#{described_class}::IDEMPOTENCY_WINDOW", 0.seconds) }

      it "counts both and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(campaign_rows("test.picks").sole.impression_count).to eq(2)
        expect(impression_audits.count).to eq(1)
      end
    end

    context "with a delivery and no idempotency window" do
      let(:row) { delivery_row(user:, key: "test.class_canceled", identity: "class/1") }
      let(:flags) do
        args = { user:, notice_class: class_canceled, row: }
        concurrently { record_impression(**args).data[:first_impression] }
      end

      before { stub_const("#{described_class}::IDEMPOTENCY_WINDOW", 0.seconds) }

      it "counts both and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(row.reload.impression_count).to eq(2)
        expect(impression_audits.count).to eq(1)
      end
    end
  end
end
