# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Failure do
  describe ".build" do
    subject(:entry) { described_class.build(code: :invalid_limit, field: :limit, details: { max: 100 }) }

    it "returns a normalized failure entry" do
      expect(entry).to eq(
        code: "invalid_limit",
        field: "limit",
        details: { max: 100 }
      )
    end
  end
end
