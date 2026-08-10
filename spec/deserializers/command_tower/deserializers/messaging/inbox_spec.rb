# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Messaging::Inbox::ListDeserializer do
  context "with an empty query" do
    subject(:result) { described_class.call({}) }

    it { expect(result).to be_success }

    it "uses defaults" do
      expect(result.input).to have_attributes(limit: 50, offset: 0, scope: "inbox")
    end
  end

  context "with invalid bulk ids" do
    subject(:result) { CommandTower::Deserializers::Messaging::Inbox::BulkIdsDeserializer.call(ids: []) }

    it { expect(result).not_to be_success }
  end
end
