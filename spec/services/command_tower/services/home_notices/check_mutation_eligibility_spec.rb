# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::CheckMutationEligibility do
  include ActiveSupport::Testing::TimeHelpers
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  subject(:result) { check_eligibility(notice_class:, row:, for_impression:) }

  let(:user) { create(:user) }
  let(:notice_class) { campaign("test.picks") }
  let(:row) { nil }
  let(:for_impression) { false }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    travel_to(start_time)
    CommandTower::HomeNotices::Catalog.load!([campaign("test.picks"), delivery("test.class_canceled")])
  end

  shared_examples "a not found failure" do
    it "fails with not found", :aggregate_failures do
      expect(result).to be_failure
      expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError)
    end
  end

  shared_examples "a pass" do
    it "passes" do
      expect(result).to be_success
    end
  end

  it_behaves_like "a pass"

  it "does not call show?" do
    notice_class.define_method(:show?) { |**| raise "boom" }
    expect(result).to be_success
  end

  describe "registration" do
    context "with no class" do
      let(:notice_class) { nil }
      let(:row) { campaign_row(user:, key: "test.gone") }

      it_behaves_like "a not found failure"
    end

    context "with a class that is not registered" do
      let(:notice_class) { campaign("test.other") }

      it_behaves_like "a not found failure"
    end

    context "with a delivery and no row" do
      let(:notice_class) { delivery("test.class_canceled") }

      it_behaves_like "a not found failure"
    end

    context "with a delivery and its row" do
      let(:notice_class) { delivery("test.class_canceled") }
      let(:row) { delivery_row(user:, key: "test.class_canceled", identity: "c/1") }

      it_behaves_like "a pass"
    end
  end

  describe "kill switch" do
    context "when the notice is switched off" do
      before { CommandTower::HomeNoticeControl.create!(key: "test.picks", enabled: false) }

      it_behaves_like "a not found failure"
    end

    context "when another notice is switched off" do
      before { CommandTower::HomeNoticeControl.create!(key: "test.class_canceled", enabled: false) }

      it_behaves_like "a pass"
    end

    context "when the controls cannot be read" do
      before do
        allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "fails with the internal error, not a not found", :aggregate_failures do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::InternalError)
      end
    end
  end

  describe "window" do
    context "with a class window that has not opened" do
      let(:notice_class) { campaign("test.picks", active: { starts_at: start_time + 1.hour, ends_at: nil }) }

      it_behaves_like "a not found failure"
    end

    context "with a class window that has closed" do
      let(:notice_class) { campaign("test.picks", active: { starts_at: nil, ends_at: start_time }) }

      it_behaves_like "a not found failure"
    end

    context "with a class window that opens now (start inclusive)" do
      let(:notice_class) do
        campaign("test.picks", active: { starts_at: start_time, ends_at: start_time + 1.hour })
      end

      it_behaves_like "a pass"
    end

    context "with a row that has ended" do
      let(:row) { campaign_row(user:, key: "test.picks", ends_at: start_time - 1.minute) }

      it_behaves_like "a not found failure"
    end

    context "with a row that has not started" do
      let(:row) { campaign_row(user:, key: "test.picks", starts_at: start_time + 1.minute) }

      it_behaves_like "a not found failure"
    end
  end

  describe "pacing state" do
    let(:for_impression) { true }

    context "when acknowledged" do
      let(:row) { campaign_row(user:, key: "test.picks", acknowledged_at: start_time - 1.day) }

      it_behaves_like "a not found failure"

      it "still passes for a mutation that is not an impression" do
        expect(check_eligibility(notice_class:, row:)).to be_success
      end
    end

    context "when dismissed into the future" do
      let(:row) { campaign_row(user:, key: "test.picks", dismissed_until: start_time + 1.day) }

      it_behaves_like "a not found failure"
    end

    context "when the dismissal has lapsed" do
      let(:row) { campaign_row(user:, key: "test.picks", dismissed_until: start_time) }

      it_behaves_like "a pass"
    end

    context "when inside the item cooldown, as right after the first impression" do
      let(:row) do
        campaign_row(user:, key: "test.picks", impression_count: 1, last_shown_at: start_time - 5.seconds)
      end

      it_behaves_like "a pass"
    end
  end
end
