# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::ResolveNotice do
  include ActiveSupport::Testing::TimeHelpers
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:period) { nil }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    travel_to(start_time)
    CommandTower::HomeNotices::Catalog.load!([campaign("test.picks", period:), delivery("test.class_canceled")])
  end

  shared_examples "a not found failure" do
    it "fails with not found", :aggregate_failures do
      expect(result).to be_failure
      expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError)
    end
  end

  describe "a public id" do
    subject(:result) { resolve_notice(user:, public_id:) }

    let!(:row) { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }
    let(:public_id) { row.public_id }

    it "resolves the user's own row and its class", :aggregate_failures do
      expect(result).to be_success
      expect(result.data[:row]).to eq(row)
      expect(result.data[:notice_class].key).to eq("test.class_canceled")
    end

    context "with another user's row" do
      let(:public_id) { delivery_row(user: other_user, key: "test.class_canceled", identity: "c/2").public_id }

      it_behaves_like "a not found failure"
    end

    context "with an unknown id" do
      let(:public_id) { "nope" }

      it_behaves_like "a not found failure"
    end

    context "with a key that is no longer registered" do
      before { CommandTower::HomeNotices::Catalog.load!([]) }

      it "returns a nil class", :aggregate_failures do
        expect(result).to be_success
        expect(result.data[:notice_class]).to be_nil
      end
    end
  end

  describe "a campaign id" do
    subject(:result) { resolve_notice(user:, campaign_key: "test.picks") }

    it "returns a nil row when the period has no row yet", :aggregate_failures do
      expect(result).to be_success
      expect(result.data[:row]).to be_nil
      expect(result.data[:notice_class].key).to eq("test.picks")
      expect(result.data[:period_key]).to eq("")
    end

    context "with rows for two users" do
      let!(:own_row) { campaign_row(user:, key: "test.picks") }

      before { campaign_row(user: other_user, key: "test.picks") }

      it "returns the user's own row for the period" do
        expect(result.data[:row]).to eq(own_row)
      end
    end

    context "with a period_key block" do
      let(:period) { ->(**) { "p-web" } }
      let!(:current) { campaign_row(user:, key: "test.picks", period_key: "p-web") }

      before { campaign_row(user:, key: "test.picks", period_key: "old") }

      it "looks up the row for the current period", :aggregate_failures do
        expect(result.data[:row]).to eq(current)
        expect(result.data[:period_key]).to eq("p-web")
      end
    end

    context "when the period_key block raises" do
      let(:period) { ->(**) { raise "boom" } }

      it_behaves_like "a not found failure"
    end

    context "with an unregistered key" do
      subject(:result) { resolve_notice(user:, campaign_key: "test.unknown") }

      it_behaves_like "a not found failure"
    end

    context "with a delivery key" do
      subject(:result) { resolve_notice(user:, campaign_key: "test.class_canceled") }

      it_behaves_like "a not found failure"
    end
  end
end
