# frozen_string_literal: true

RSpec.describe CommandTower::Clients::SerializedRequest do
  describe ".build" do
    subject(:serialized) do
      described_class.build(
        query: { page: 1 },
        body: { name: "widget" },
        headers: { "X-Test" => "1" }
      )
    end

    it "returns an immutable value object with query, body, and headers" do
      expect(serialized).to be_a(described_class)
      expect(serialized.query).to eq(page: 1)
      expect(serialized.body).to eq(name: "widget")
      expect(serialized.headers).to eq("X-Test" => "1")
    end

    context "with no arguments" do
      subject(:blank) { described_class.build }

      it "defaults query and headers to empty hashes and body to nil" do
        expect(blank.query).to eq({})
        expect(blank.body).to be_nil
        expect(blank.headers).to eq({})
      end
    end
  end
end
