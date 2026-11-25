# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::PruneEnded do
  include ActiveSupport::Testing::TimeHelpers
  include HomeNoticeSelectSpecHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:old) { start_time - 181.days }
  let(:recent) { start_time - 10.days }
  let(:notices) { [campaign("test.picks"), delivery("test.class_canceled")] }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    travel_to(start_time)
    CommandTower::HomeNotices::Catalog.load!(notices)
  end

  describe "campaign rows" do
    it "prunes a never-shown unacknowledged row (NULL columns do not hide it)" do
      expect(pruned?(aged(campaign_row(user:, key: "test.picks", period_key: "week-1"), old))).to be(true)
    end

    it "keeps an unacknowledged row that was shown recently" do
      expect(
        pruned?(aged(campaign_row(user:, key: "test.picks", period_key: "week-1", last_shown_at: recent), old))
      ).to be(false)
    end

    it "keeps a recent unacknowledged row" do
      expect(pruned?(aged(campaign_row(user:, key: "test.picks", period_key: "week-1"), recent))).to be(false)
    end

    it "keeps an old acknowledged row of a live campaign" do
      expect(
        pruned?(aged(campaign_row(user:, key: "test.picks", period_key: "week-1", acknowledged_at: old), old))
      ).to be(false)
    end

    it "prunes an old acknowledged row whose key is unregistered" do
      expect(
        pruned?(aged(campaign_row(user:, key: "test.gone", period_key: "week-1", acknowledged_at: old), old))
      ).to be(true)
    end

    context "when the class window has ended" do
      let(:notices) { [campaign("test.picks", active: { ends_at: start_time - 1.day })] }

      it "prunes an old acknowledged row" do
        expect(
          pruned?(aged(campaign_row(user:, key: "test.picks", period_key: "week-1", acknowledged_at: old), old))
        ).to be(true)
      end
    end

    it "prunes an old acknowledged row whose own window has ended" do
      expect(
        pruned?(aged(campaign_row(user:, key: "test.picks", acknowledged_at: old, ends_at: old), old))
      ).to be(true)
    end
  end

  describe "delivery rows" do
    it "prunes an old acknowledged delivery" do
      expect(
        pruned?(aged(delivery_row(user:, key: "test.class_canceled", identity: "a", acknowledged_at: old), old))
      ).to be(true)
    end

    it "prunes an old dismissed delivery" do
      expect(
        pruned?(aged(delivery_row(user:, key: "test.class_canceled", identity: "a", dismissed_until: old), old))
      ).to be(true)
    end

    it "prunes an old never-shown delivery past its ends_at" do
      expect(
        pruned?(
          aged(delivery_row(user:, key: "test.class_canceled", identity: "a", ends_at: start_time - 1.day), old)
        )
      ).to be(true)
    end

    it "keeps an old open delivery" do
      expect(pruned?(aged(delivery_row(user:, key: "test.class_canceled", identity: "a"), old))).to be(false)
    end

    it "keeps an ended delivery with recent activity" do
      expect(
        pruned?(aged(delivery_row(user:, key: "test.class_canceled", identity: "a", acknowledged_at: recent), old))
      ).to be(false)
    end
  end

  context "with a small batch size" do
    before do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      3.times { |i| aged(campaign_row(user:, key: "test.picks", period_key: "week-#{i}"), old) }
    end

    it "deletes in batches and reports the count", :aggregate_failures do
      expect(described_class.call.data[:deleted]).to eq(3)
      expect(CommandTower::HomeNotice.count).to eq(0)
    end
  end

  it "leaves another user's recent rows alone" do
    expect(pruned?(campaign_row(user: other_user, key: "test.picks", period_key: "week-1"))).to be(false)
  end
end
