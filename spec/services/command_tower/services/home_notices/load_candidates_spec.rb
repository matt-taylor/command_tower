# frozen_string_literal: true

# Drop rules are covered in select_spec.rb; this pins what is gathered before them.
RSpec.describe CommandTower::Services::HomeNotices::LoadCandidates do
  include ActiveSupport::Testing::TimeHelpers
  include HomeNoticeSelectSpecHelpers

  let(:user) { create(:user) }
  let(:notices) { [campaign("test.picks", period: ->(**) { "w1" }), delivery("test.class_canceled")] }
  let(:result) { described_class.call(user:, request_context: request_context) }
  let(:pairs) { result.data[:pairs].map { |klass, row| [klass.key, row&.identity || row&.period_key] } }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    travel_to(start_time)
    CommandTower::HomeNotices::Catalog.load!(notices)
    campaign_row(user:, key: "test.picks", period_key: "w0", acknowledged_at: start_time - 1.week)
    delivery_row(user:, key: "test.class_canceled", identity: "c/1")
    delivery_row(user:, key: "test.class_canceled", identity: "c/2", acknowledged_at: start_time - 1.minute)
  end

  it "gathers open deliveries and each campaign without a row for another period" do
    expect(pairs).to contain_exactly(["test.class_canceled", "c/1"], ["test.picks", nil])
  end

  context "with a row for the current period" do
    before { campaign_row(user:, key: "test.picks", period_key: "w1") }

    it "pairs the campaign with that row" do
      expect(pairs).to include(["test.picks", "w1"])
    end
  end
end
