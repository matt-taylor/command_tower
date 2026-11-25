# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::ReadControls do
  let(:keys) { %w[test.one test.two test.three] }
  let(:result) { described_class.call(keys:) }

  before do
    CommandTower::HomeNoticeControl.create!(key: "test.one", enabled: false)
    CommandTower::HomeNoticeControl.create!(key: "test.two", enabled: true)
    CommandTower::HomeNoticeControl.create!(key: "test.other", enabled: false)
  end

  it "returns only the requested keys that are switched off", :aggregate_failures do
    expect(result).to be_success
    expect(result.data[:disabled_keys]).to eq(Set["test.one"])
  end

  context "with no keys" do
    let(:keys) { [] }

    it "returns an empty set" do
      expect(result.data[:disabled_keys]).to eq(Set.new)
    end
  end

  context "when the controls table cannot be read" do
    before do
      allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
    end

    it "fails with an internal error that keeps the cause", :aggregate_failures do
      expect(result).to be_failure
      expect(result.errors.first).to be_a(CommandTower::Errors::InternalError)
      expect(result.errors.first.cause).to be_a(ActiveRecord::ConnectionNotEstablished)
    end
  end
end
