# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Dismiss do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user) }
  let(:until_time) { start_time + described_class::DISMISSAL_DURATION }

  describe "an existing dismissible campaign row" do
    let(:picks) { campaign("test.picks") }
    let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48", impression_count: 1) }
    let!(:result) { dismiss_notice(user:, notice_class: picks, row:) }

    it "dismisses it", :aggregate_failures do
      expect(result.data).to include(
        dismissed: true, recorded: true, public_id: row.public_id, dismissed_until: until_time
      )
      expect(row.reload).to have_attributes(dismissed_until: until_time, acknowledged_at: nil)
    end

    it "audits it with ids only", :aggregate_failures do
      expect(dismissal_audits.sole).to have_attributes(
        affected_user_id: user.id, retention: "ninety_days", user_history: false,
        metadata: { "notice_id" => row.public_id, "key" => "test.picks", "kind" => "campaign",
                    "severity" => "dismissible" }
      )
    end

    it "is an idempotent success the second time, with no second audit", :aggregate_failures do
      expect(dismiss_notice(user:, notice_class: picks, row:, at: start_time + 1.hour).data)
        .to include(recorded: false, dismissed_until: until_time)
      expect(row.reload.dismissed_until).to eq(until_time)
      expect(dismissal_audits.count).to eq(1)
    end

    it "dismisses again once the dismissal has lapsed", :aggregate_failures do
      expect(dismiss_notice(user:, notice_class: picks, row:, at: until_time + 1.minute).data)
        .to include(recorded: true)
      expect(dismissal_audits.count).to eq(2)
    end
  end

  describe "a blocking notice" do
    let!(:row) { campaign_row(user:, key: "test.terms", period_key: "week-48") }

    it "fails with a validation error and writes nothing", :aggregate_failures do
      expect(dismiss_notice(user:, notice_class: campaign("test.terms", kind: :blocking), row:).errors.first)
        .to be_a(CommandTower::Errors::ValidationError)
      expect(row.reload.dismissed_until).to be_nil
      expect(dismissal_audits.count).to eq(0)
    end
  end

  describe "a notice whose show? raises" do
    let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

    let(:klass) { campaign("test.picks", shows: ->(**) { raise "show? failed" }) }

    it "dismisses it anyway" do
      expect(dismiss_notice(user:, notice_class: klass, row:).data).to include(recorded: true)
    end
  end

  describe "a campaign with no row in the period" do
    before { dismiss_notice(user:, notice_class: campaign("test.picks")) }

    it "creates the row already dismissed, with an audit", :aggregate_failures do
      expect(campaign_rows("test.picks").sole).to have_attributes(
        kind: "campaign", period_key: "week-48", dismissed_until: until_time, impression_count: 0
      )
      expect(dismissal_audits.count).to eq(1)
    end
  end

  describe "an existing delivery row" do
    let!(:row) { delivery_row(user:, key: "test.class_canceled", identity: "class/1") }

    it "dismisses it and audits it as a delivery", :aggregate_failures do
      dismiss_notice(user:, notice_class: delivery("test.class_canceled"), row:)
      expect(row.reload.dismissed_until).to eq(until_time)
      expect(dismissal_audits.sole.metadata).to include("kind" => "delivery", "severity" => "dismissible")
    end
  end

  describe "a delivery without a row" do
    it "fails with not found" do
      expect(dismiss_notice(user:, notice_class: delivery("test.class_canceled")).errors.first)
        .to be_a(CommandTower::Errors::NotFoundError)
    end
  end

  [true, nil].each do |flag|
    context "when impersonating is #{flag.inspect}" do
      let!(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

      it "fails with forbidden and writes nothing", :aggregate_failures do
        expect(dismiss_notice(user:, notice_class: campaign("test.picks"), row:, impersonating: flag).errors.first)
          .to be_a(CommandTower::Errors::ForbiddenError)
        expect(row.reload.dismissed_until).to be_nil
        expect(dismissal_audits.count).to eq(0)
      end
    end
  end

  context "when the audit cannot be written" do
    before { allow(CommandTower::Audit::Emit).to receive(:call).and_raise(ActiveRecord::StatementInvalid) }

    let(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }

    it "rolls an update back with the transaction", :aggregate_failures do
      expect { dismiss_notice(user:, notice_class: campaign("test.picks"), row:) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(row.reload.dismissed_until).to be_nil
    end

    it "rolls a new campaign row back with the transaction", :aggregate_failures do
      expect { dismiss_notice(user:, notice_class: campaign("test.picks")) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(campaign_rows("test.picks").count).to eq(0)
    end
  end

  describe "two concurrent dismissals" do
    self.use_transactional_tests = false

    around { |example| with_concurrent_pool { example.run } }

    context "with an existing row" do
      let(:row) { campaign_row(user:, key: "test.picks", period_key: "week-48") }
      let(:flags) do
        args = { user:, notice_class: campaign("test.picks"), row: }
        concurrently { dismiss_notice(**args).data[:recorded] }
      end

      it "dismisses and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(row.reload.dismissed_until).to eq(until_time)
        expect(dismissal_audits.count).to eq(1)
      end
    end

    context "with no row yet" do
      let(:flags) do
        args = { user:, notice_class: campaign("test.picks") }
        concurrently { dismiss_notice(**args).data[:recorded] }
      end

      it "creates one row and audits once", :aggregate_failures do
        expect(flags).to contain_exactly(true, false)
        expect(campaign_rows("test.picks").sole.dismissed_until).to eq(until_time)
        expect(dismissal_audits.count).to eq(1)
      end
    end
  end
end
