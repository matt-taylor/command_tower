# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Select do
  include ActiveSupport::Testing::TimeHelpers
  include HomeNoticeSelectSpecHelpers

  let(:user) { create(:user) }
  let(:notices) { [campaign("test.picks"), delivery("test.class_canceled")] }
  let(:events) { [] }
  let(:result) { run_select(user:) }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    listener = lambda do |name, _start, _finish, _id, payload|
      events << [name.delete_prefix("command_tower.home_notices."), payload]
    end
    ActiveSupport::Notifications.subscribed(listener, /\Acommand_tower\.home_notices\./) { example.run }
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    travel_to(start_time)
    CommandTower::HomeNotices::Catalog.load!(notices)
  end

  describe "candidates" do
    it "includes a registered campaign that has no row yet, with no record", :aggregate_failures do
      expect(result).to be_success
      expect(candidate_keys(result)).to eq(["test.picks"])
      expect(candidate_for(result, "test.picks").record).to be_nil
    end

    it "reports the controls as available" do
      expect(result.data[:controls_available]).to be(true)
    end

    context "with a campaign row for the current period" do
      let!(:row) { campaign_row(user:, key: "test.picks", impression_count: 1) }

      it "pairs the campaign with a read-only snapshot of the row", :aggregate_failures do
        expect(candidate_for(result, "test.picks").record).to be_a(CommandTower::HomeNotices::NoticeRecord)
        expect(candidate_for(result, "test.picks").record.public_id).to eq(row.public_id)
      end
    end

    context "with an open delivery row" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }

      it "includes the delivery with its record" do
        expect(candidate_for(result, "test.class_canceled").record.identity).to eq("c/1")
      end
    end

    context "with a delivery row whose key is not registered" do
      before { delivery_row(user:, key: "test.retired", identity: "r/1") }

      it "drops it" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "with a delivery row that belongs to another user" do
      before { delivery_row(user: create(:user), key: "test.class_canceled", identity: "c/1") }

      it "ignores it" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when no notices are registered" do
      let(:notices) { [] }

      it "has no candidates" do
        expect(result.data[:candidates]).to eq([])
      end
    end
  end

  describe "kill switch" do
    before { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }

    context "when a campaign is switched off" do
      before { CommandTower::HomeNoticeControl.create!(key: "test.picks", enabled: false) }

      it "drops the campaign only" do
        expect(candidate_keys(result)).to eq(["test.class_canceled"])
      end
    end

    context "when a delivery is switched off" do
      before { CommandTower::HomeNoticeControl.create!(key: "test.class_canceled", enabled: false) }

      it "drops the delivery only" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when a control row is enabled" do
      before { CommandTower::HomeNoticeControl.create!(key: "test.picks", enabled: true) }

      it "keeps the notice" do
        expect(candidate_keys(result)).to contain_exactly("test.picks", "test.class_canceled")
      end
    end

    context "when there is no control row" do
      it "treats the notice as enabled" do
        expect(candidate_keys(result)).to contain_exactly("test.picks", "test.class_canceled")
      end
    end
  end

  describe "controls unavailable" do
    before do
      allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
    end

    it "fails closed with no candidates", :aggregate_failures do
      expect(result).to be_success
      expect(result.data[:candidates]).to eq([])
      expect(result.data[:controls_available]).to be(false)
    end

    context "when logging" do
      before { result }

      it "logs controls_unavailable with the user id and error class, at error level" do
        expect(events.to_h["controls_unavailable"]).to include(
          user_id: user.id, error_class: "ActiveRecord::ConnectionNotEstablished", log_level: :error
        )
      end
    end
  end

  describe "class window" do
    context "when the window has not started" do
      let(:notices) { [campaign("test.picks", active: { starts_at: start_time + 1.hour })] }

      it "drops the notice" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "when time reaches starts_at" do
      let(:notices) { [campaign("test.picks", active: { starts_at: start_time + 1.hour })] }

      before { travel 1.hour }

      it "keeps the notice (starts_at is inclusive)" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when the window is still open" do
      let(:notices) { [campaign("test.picks", active: { ends_at: start_time + 1.hour })] }

      before { travel 1.hour - 1.second }

      it "keeps the notice" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when time reaches ends_at" do
      let(:notices) { [campaign("test.picks", active: { ends_at: start_time + 1.hour })] }

      before { travel 1.hour }

      it "drops the notice (ends_at is exclusive)" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "when a delivery class window has ended" do
      let(:notices) { [delivery("test.class_canceled", active: { ends_at: start_time - 1.minute })] }

      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }

      it "drops the delivery" do
        expect(candidate_keys(result)).to be_empty
      end
    end
  end

  describe "delivery row window" do
    context "when the delivery starts later" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1", starts_at: start_time + 30.minutes) }

      it "drops it" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when time reaches the delivery starts_at" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", starts_at: start_time + 30.minutes)
        travel 30.minutes
      end

      it "includes it" do
        expect(candidate_keys(result)).to include("test.class_canceled")
      end
    end

    context "when the delivery has not ended yet" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 2.hours)
        travel 2.hours - 1.second
      end

      it "includes it" do
        expect(candidate_keys(result)).to include("test.class_canceled")
      end
    end

    context "when time reaches the delivery ends_at" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 2.hours)
        travel 2.hours
      end

      it "drops it" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end
  end

  describe "acknowledged" do
    context "with an acknowledged campaign row" do
      before { campaign_row(user:, key: "test.picks", acknowledged_at: start_time - 1.day) }

      it "drops the campaign" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "with an acknowledged delivery row" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", acknowledged_at: start_time - 1.minute)
      end

      it "drops the delivery" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end
  end

  describe "dismissed until" do
    before { campaign_row(user:, key: "test.picks", dismissed_until: start_time + 1.day) }

    context "when dismissed_until is still in the future" do
      before { travel 1.day - 1.second }

      it "drops the notice" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "when time reaches dismissed_until" do
      before { travel 1.day }

      it "shows the notice again" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "with a dismissed delivery" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", dismissed_until: start_time + 1.hour)
      end

      it "drops the delivery" do
        expect(candidate_keys(result)).to be_empty
      end
    end
  end

  describe "period impressions" do
    context "when the period count is below max" do
      before { campaign_row(user:, key: "test.picks", impression_count: 2, last_shown_at: start_time - 5.hours) }

      it "keeps the campaign" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "when the period count reaches max" do
      before { campaign_row(user:, key: "test.picks", impression_count: 3, last_shown_at: start_time - 5.hours) }

      it "drops the campaign" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "with a period_key whose current period is at max" do
      let(:notices) do
        [campaign("test.picks", period: ->(context:, **) { context.now >= start_time + 7.days ? "w2" : "w1" })]
      end

      before do
        campaign_row(user:, key: "test.picks", period_key: "w1", impression_count: 3,
                     last_shown_at: start_time - 5.hours)
      end

      it "drops the campaign" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "with a period_key after the period changes" do
      let(:notices) do
        [campaign("test.picks", period: ->(context:, **) { context.now >= start_time + 7.days ? "w2" : "w1" })]
      end

      before do
        campaign_row(user:, key: "test.picks", period_key: "w1", impression_count: 3,
                     last_shown_at: start_time - 5.hours)
        travel 7.days
      end

      it "resets: the campaign is a candidate with no record", :aggregate_failures do
        expect(candidate_keys(result)).to eq(["test.picks"])
        expect(candidate_for(result, "test.picks").record).to be_nil
      end
    end

    context "with an over-long period_key" do
      let(:long_key) { "p" * 300 }
      let(:notices) { [campaign("test.picks", period: ->(**) { long_key })] }

      before do
        campaign_row(user:, key: "test.picks", period_key: long_key, impression_count: 3,
                     last_shown_at: start_time - 5.hours)
      end

      it "matches the row by its stored form" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "when the period_key block raises" do
      let(:notices) { [campaign("test.picks", period: ->(**) { raise ArgumentError, "secret detail" })] }

      before { result }

      it "skips the campaign" do
        expect(candidate_keys(result)).to be_empty
      end

      it "logs period_key_failed with the key and error class" do
        expect(events.to_h["period_key_failed"]).to include(notice_key: "test.picks", error_class: "ArgumentError")
      end

      it "does not log the error message" do
        expect(events.to_h["period_key_failed"].values).not_to include("secret detail")
      end
    end
  end

  describe "item cooldown" do
    before { campaign_row(user:, key: "test.picks", impression_count: 1, last_shown_at: start_time) }

    it "drops the campaign right after an impression" do
      expect(candidate_keys(result)).to be_empty
    end

    context "when just under the cooldown has passed" do
      before { travel 4.hours - 1.second }

      it "still drops the campaign" do
        expect(candidate_keys(result)).to be_empty
      end
    end

    context "when the cooldown has passed" do
      before { travel 4.hours }

      it "keeps the campaign" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "with a campaign that declares no impressions" do
      let(:notices) { [campaign("test.picks", kind: :blocking, pacing: nil)] }

      it "applies no pacing" do
        expect(candidate_keys(result)).to eq(["test.picks"])
      end
    end

    context "with a delivery shown just now" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", impression_count: 9, last_shown_at: start_time)
      end

      it "applies no item pacing to deliveries" do
        expect(candidate_keys(result)).to eq(["test.class_canceled"])
      end
    end
  end

  describe "open-delivery cap" do
    around do |example|
      previous = CommandTower.config.home_notices.max_open_deliveries
      CommandTower.config.home_notices.max_open_deliveries = 2
      example.run
    ensure
      CommandTower.config.home_notices.max_open_deliveries = previous
    end

    let(:notices) { [delivery("test.class_canceled")] }

    context "with more open deliveries than the cap" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/3", created_at: start_time - 1.hour)
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", created_at: start_time - 3.hours)
        delivery_row(user:, key: "test.class_canceled", identity: "c/2", created_at: start_time - 2.hours)
      end

      it "takes the oldest up to the cap" do
        expect(candidate_identities(result)).to eq(%w[c/1 c/2])
      end
    end

    context "with acknowledged and ended deliveries" do
      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", created_at: start_time - 5.hours,
                     acknowledged_at: start_time - 1.hour)
        delivery_row(user:, key: "test.class_canceled", identity: "c/2", created_at: start_time - 4.hours,
                     ends_at: start_time - 1.minute)
        delivery_row(user:, key: "test.class_canceled", identity: "c/3", created_at: start_time - 3.hours)
        delivery_row(user:, key: "test.class_canceled", identity: "c/4", created_at: start_time - 2.hours)
        delivery_row(user:, key: "test.class_canceled", identity: "c/5", created_at: start_time - 1.hour)
      end

      it "does not let closed deliveries use a slot" do
        expect(candidate_identities(result)).to eq(%w[c/3 c/4])
      end
    end
  end

  describe "priority order" do
    context "with different priorities" do
      let(:notices) { [campaign("test.low", rank: 10), campaign("test.high", rank: 50)] }

      it "orders candidates highest priority first" do
        expect(candidate_keys(result)).to eq(%w[test.high test.low])
      end

      it "picks the highest priority" do
        expect(picked_key(result, :dismissible)).to eq("test.high")
      end
    end

    context "with equal priorities" do
      let(:notices) { [delivery("test.class_canceled")] }

      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/new", created_at: start_time - 1.hour)
        delivery_row(user:, key: "test.class_canceled", identity: "c/old", created_at: start_time - 3.hours)
      end

      it "breaks the tie to the oldest row" do
        expect(result.data[:dismissible].record.identity).to eq("c/old")
      end
    end

    context "with a campaign that has no row and a delivery of equal priority" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1", created_at: start_time - 1.day) }

      it "counts the campaign with no row as newest" do
        expect(picked_key(result, :dismissible)).to eq("test.class_canceled")
      end
    end
  end

  describe "blocking pick" do
    let(:terms_options) { {} }
    let(:notices) do
      [
        campaign("test.terms", kind: :blocking, rank: 90, pacing: nil, **terms_options),
        campaign("test.privacy", kind: :blocking, rank: 50, pacing: nil)
      ]
    end

    it "picks the highest priority blocking notice with its document and hash", :aggregate_failures do
      expect(picked_key(result, :blocking)).to eq("test.terms")
      expect(result.data[:blocking].document).to be_a(CommandTower::UI::Document)
      expect(result.data[:blocking].content_hash).to match(/\A\h{64}\z/)
    end

    it "picks no dismissible notice when none is a candidate" do
      expect(result.data[:dismissible]).to be_nil
    end

    context "when show? is false" do
      let(:terms_options) { { shows: ->(**) { false } } }

      it "moves to the next notice" do
        expect(picked_key(result, :blocking)).to eq("test.privacy")
      end
    end

    context "when show? raises" do
      let(:terms_options) { { shows: ->(**) { raise ArgumentError, "secret detail" } } }

      before { result }

      it "treats it as not shown and moves on" do
        expect(picked_key(result, :blocking)).to eq("test.privacy")
      end

      it "logs show_if_failed with the key and error class, at error level" do
        expect(events.to_h["show_if_failed"]).to include(
          notice_key: "test.terms", error_class: "ArgumentError", log_level: :error
        )
      end

      it "does not log the error message" do
        expect(events.to_h["show_if_failed"].values).not_to include("secret detail")
      end
    end

    context "when the composed document fails the blocking profile" do
      let(:terms_options) { { body: internal_link_body } }

      before { result }

      it "skips the notice" do
        expect(picked_key(result, :blocking)).to eq("test.privacy")
      end

      it "logs blocking_invalid with the key" do
        expect(events.to_h["blocking_invalid"]).to include(notice_key: "test.terms")
      end
    end

    context "when the client catalog is below 2" do
      let(:terms_options) { { shows: ->(**) { raise ArgumentError, "must not run" } } }
      let(:result) { run_select(user:, ui_catalog: 1) }

      before { result }

      it "picks nothing", :aggregate_failures do
        expect(result.data[:blocking]).to be_nil
        expect(result.data[:dismissible]).to be_nil
      end

      it "does not evaluate show?" do
        expect(events.to_h).not_to have_key("show_if_failed")
      end
    end

    context "when a dismissible notice was shown just now" do
      let(:notices) do
        [campaign("test.terms", kind: :blocking, rank: 90, pacing: nil), delivery("test.class_canceled")]
      end

      before do
        delivery_row(user:, key: "test.class_canceled", identity: "c/0", acknowledged_at: start_time,
                     last_shown_at: start_time)
      end

      it "ignores the global cooldown" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end
  end

  describe "UTC daily cap" do
    let(:notices) do
      [
        campaign("test.terms", kind: :blocking, rank: 90, pacing: nil),
        campaign("test.privacy", kind: :blocking, rank: 50, pacing: nil),
        delivery("test.cookies", kind: :blocking, rank: 10),
        campaign("test.picks")
      ]
    end
    let(:started_at) { start_time.beginning_of_day + 1.hour }

    context "with one blocking notice started today" do
      before { campaign_row(user:, key: "test.privacy", first_shown_at: started_at, acknowledged_at: started_at) }

      it "starts another" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end

    context "with a blocking notice started on an earlier day and not acknowledged" do
      before do
        campaign_row(user:, key: "test.privacy", first_shown_at: started_at, acknowledged_at: started_at)
        delivery_row(user:, key: "test.cookies", identity: "k/1", first_shown_at: started_at,
                     acknowledged_at: started_at)
        campaign_row(user:, key: "test.terms", first_shown_at: started_at - 2.days)
      end

      it "re-serves it until acknowledged" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end

    context "with dismissible and unregistered rows first shown today" do
      before do
        campaign_row(user:, key: "test.picks", period_key: "old", first_shown_at: started_at)
        campaign_row(user:, key: "test.retired", first_shown_at: started_at)
      end

      it "does not count them" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end
  end

  describe "UTC daily cap reached (two blocking notices started today)" do
    let(:notices) do
      [
        campaign("test.terms", kind: :blocking, rank: 90, pacing: nil),
        campaign("test.privacy", kind: :blocking, rank: 50, pacing: nil),
        delivery("test.cookies", kind: :blocking, rank: 10)
      ]
    end
    let(:started_at) { start_time.beginning_of_day + 1.hour }

    before do
      campaign_row(user:, key: "test.privacy", first_shown_at: started_at, acknowledged_at: started_at)
      delivery_row(user:, key: "test.cookies", identity: "k/1", first_shown_at: started_at,
                   acknowledged_at: started_at)
    end

    it "does not start another" do
      expect(result.data[:blocking]).to be_nil
    end

    context "when the day is almost over" do
      before { travel_to(start_time.end_of_day) }

      it "still does not start another" do
        expect(result.data[:blocking]).to be_nil
      end
    end

    context "when the next UTC day begins" do
      before { travel_to(start_time.beginning_of_day + 1.day) }

      it "starts the next notice" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end

    context "when the top notice was already started" do
      before { campaign_row(user:, key: "test.terms", first_shown_at: started_at + 1.hour) }

      it "re-serves it" do
        expect(picked_key(result, :blocking)).to eq("test.terms")
      end
    end
  end

  describe "global cooldown running (a dismissible notice shown 2 hours ago)" do
    let(:notices) { [campaign("test.picks", rank: 50), delivery("test.class_canceled", rank: 80)] }

    before do
      delivery_row(user:, key: "test.class_canceled", identity: "c/0", acknowledged_at: start_time - 2.hours,
                   last_shown_at: start_time - 2.hours)
    end

    it "picks nothing while the cooldown runs" do
      expect(result.data[:dismissible]).to be_nil
    end

    context "when just under the cooldown has passed" do
      before { travel 6.hours - 1.second }

      it "still picks nothing" do
        expect(result.data[:dismissible]).to be_nil
      end
    end

    context "when the cooldown has passed" do
      before { travel 6.hours }

      it "picks a notice" do
        expect(picked_key(result, :dismissible)).to eq("test.picks")
      end
    end

    context "with a delivery that ends before the cooldown clears" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 6.hours) }

      it "bypasses the cooldown for that delivery" do
        expect(result.data[:dismissible].record.identity).to eq("c/1")
      end
    end

    context "with a delivery that ends after the cooldown clears" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 7.hours) }

      it "picks nothing" do
        expect(result.data[:dismissible]).to be_nil
      end
    end

    context "with a delivery that has no ends_at" do
      before { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }

      it "picks nothing" do
        expect(result.data[:dismissible]).to be_nil
      end
    end
  end

  describe "dismissible pick" do
    let(:notices) { [campaign("test.picks", rank: 50), delivery("test.class_canceled", rank: 80)] }

    context "with no dismissible impression yet" do
      it "picks a notice" do
        expect(picked_key(result, :dismissible)).to eq("test.picks")
      end
    end

    context "with only a blocking notice shown just now" do
      let(:notices) { [campaign("test.picks"), campaign("test.terms", kind: :blocking, pacing: nil)] }

      before { campaign_row(user:, key: "test.terms", last_shown_at: start_time, acknowledged_at: start_time) }

      it "does not start the global cooldown" do
        expect(picked_key(result, :dismissible)).to eq("test.picks")
      end
    end

    context "when the top notice's show? is false" do
      let(:notices) do
        [campaign("test.picks", rank: 50, shows: ->(**) { false }), campaign("test.update", rank: 10)]
      end

      it "picks the next notice" do
        expect(picked_key(result, :dismissible)).to eq("test.update")
      end
    end

    context "when the top notice's show? raises" do
      let(:notices) do
        [campaign("test.picks", rank: 50, shows: ->(**) { raise ArgumentError }), campaign("test.update", rank: 10)]
      end

      before { result }

      it "picks the next notice" do
        expect(picked_key(result, :dismissible)).to eq("test.update")
      end

      it "logs show_if_failed at warn level" do
        expect(events.to_h["show_if_failed"]).to include(notice_key: "test.picks", log_level: :warn)
      end
    end
  end

  # Doc 03 §7 example: global cooldown 8 h, one Home load per row.
  describe "doc 03 selection walk-through" do
    let(:notices) do
      [
        campaign("test.picks", rank: 50, pacing: { max: 4, cooldown: 12.hours }),
        campaign("test.update", rank: 10, pacing: { max: 6, cooldown: 6.hours }),
        delivery("test.class_canceled", rank: 80),
        campaign("test.terms", kind: :blocking, rank: 90, pacing: nil, active: { starts_at: start_time + 5.hours })
      ]
    end

    context "when at 0 h" do
      it "shows Make your picks by priority", :aggregate_failures do
        expect(picked_key(result, :dismissible)).to eq("test.picks")
        expect(result.data[:blocking]).to be_nil
      end
    end

    context "when at 2 h" do
      before do
        campaign_row(user:, key: "test.picks", impression_count: 1, first_shown_at: start_time,
                     last_shown_at: start_time)
        travel 2.hours
      end

      it "shows nothing: Update app waits for the global cooldown", :aggregate_failures do
        expect(candidate_keys(result)).to eq(["test.update"])
        expect(result.data[:dismissible]).to be_nil
      end
    end

    context "when at 3 h" do
      before do
        campaign_row(user:, key: "test.picks", impression_count: 1, first_shown_at: start_time,
                     last_shown_at: start_time)
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 5.hours)
        travel 3.hours
      end

      it "shows Class canceled: it ends before the cooldown clears" do
        expect(picked_key(result, :dismissible)).to eq("test.class_canceled")
      end
    end

    context "when at 5 h" do
      before do
        campaign_row(user:, key: "test.picks", impression_count: 1, first_shown_at: start_time,
                     last_shown_at: start_time)
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 5.hours,
                     impression_count: 1, first_shown_at: start_time + 3.hours, last_shown_at: start_time + 3.hours)
        travel 5.hours
      end

      it "shows Terms: blocking bypasses the cooldown", :aggregate_failures do
        expect(picked_key(result, :blocking)).to eq("test.terms")
        expect(result.data[:dismissible]).to be_nil
      end
    end

    context "when at 11 h" do
      before do
        campaign_row(user:, key: "test.picks", impression_count: 1, first_shown_at: start_time,
                     last_shown_at: start_time)
        delivery_row(user:, key: "test.class_canceled", identity: "c/1", ends_at: start_time + 5.hours,
                     impression_count: 1, first_shown_at: start_time + 3.hours, last_shown_at: start_time + 3.hours)
        campaign_row(user:, key: "test.terms", impression_count: 1, first_shown_at: start_time + 5.hours,
                     last_shown_at: start_time + 5.hours, acknowledged_at: start_time + 5.hours)
        travel 11.hours
      end

      it "shows Update app: the cooldown has cleared", :aggregate_failures do
        expect(picked_key(result, :dismissible)).to eq("test.update")
        expect(result.data[:blocking]).to be_nil
      end
    end
  end

  describe "show? budget" do
    context "when show? takes longer than 50 ms" do
      let(:notices) { [campaign("test.picks", shows: ->(**) { sleep(0.06) && true })] }

      before { result }

      it "still uses the answer" do
        expect(picked_key(result, :dismissible)).to eq("test.picks")
      end

      it "logs show_if_slow with the key and elapsed ms", :aggregate_failures do
        expect(events.to_h["show_if_slow"]).to include(notice_key: "test.picks")
        expect(events.to_h["show_if_slow"][:ms]).to be > 50
      end
    end

    context "when show? is fast" do
      before { result }

      it "does not log show_if_slow" do
        expect(events.to_h).not_to have_key("show_if_slow")
      end
    end
  end

  describe "selected log" do
    let(:notices) { [campaign("test.terms", kind: :blocking, pacing: nil), campaign("test.picks")] }

    context "with picks" do
      before { result }

      it "logs the picked keys and the candidate count" do
        expect(events.to_h["selected"]).to include(
          user_id: user.id, blocking_key: "test.terms", dismissible_key: "test.picks", candidate_count: 2
        )
      end

      it "logs no document content" do
        expect(events.to_h["selected"].keys).not_to include(:document, :content_hash)
      end
    end

    context "when the controls are unavailable" do
      before do
        allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
        result
      end

      it "picks nothing and logs no keys", :aggregate_failures do
        expect(result.data.values_at(:blocking, :dismissible)).to eq([nil, nil])
        expect(events.to_h["selected"]).to include(blocking_key: nil, dismissible_key: nil, candidate_count: 0)
      end
    end
  end

  # Design D5 known overshoot: concurrent GETs can each select a different unstarted blocking
  # notice before either impression lands, so the daily cap is exceeded by one per concurrent request.
  describe "documented daily cap overshoot" do
    around do |example|
      previous = CommandTower.config.home_notices.blocking_daily_cap
      CommandTower.config.home_notices.blocking_daily_cap = 1
      example.run
    ensure
      CommandTower.config.home_notices.blocking_daily_cap = previous
    end

    # Each notice shows on one platform only, so requests from different devices pick different ones.
    let(:notices) do
      [
        campaign("test.terms", kind: :blocking, rank: 90, pacing: nil, shows: shown_on("ios")),
        campaign("test.privacy", kind: :blocking, rank: 50, pacing: nil, shows: shown_on("web")),
        campaign("test.cookies", kind: :blocking, rank: 10, pacing: nil, shows: shown_on("android"))
      ]
    end
    let(:picks_by_platform) do
      %w[ios web android].index_with { |platform| picked_key(run_select(user:, platform:), :blocking) }
    end

    it "lets two requests before any impression each pick a different unstarted notice" do
      expect(picks_by_platform.values_at("ios", "web")).to eq(%w[test.terms test.privacy])
    end

    context "when both impressions have landed" do
      before do
        campaign_row(user:, key: "test.terms", first_shown_at: start_time)
        campaign_row(user:, key: "test.privacy", first_shown_at: start_time)
      end

      it "keeps re-serving both started notices, over the cap of 1" do
        expect(picks_by_platform.values_at("ios", "web")).to eq(%w[test.terms test.privacy])
      end

      it "starts no further notice" do
        expect(picks_by_platform["android"]).to be_nil
      end
    end
  end
end
