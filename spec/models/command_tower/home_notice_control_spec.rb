# frozen_string_literal: true

RSpec.describe CommandTower::HomeNoticeControl do
  it "defaults to enabled" do
    expect(described_class.create!(key: "welcome").enabled).to be(true)
  end

  context "with an existing control" do
    let!(:control) { described_class.create!(key: "welcome") }

    it "is keyed by key" do
      expect(described_class.find("welcome")).to eq(control)
    end

    it "rejects a duplicate key" do
      expect { described_class.create!(key: "welcome") }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "requires a key" do
    expect(described_class.new).not_to be_valid
  end
end
