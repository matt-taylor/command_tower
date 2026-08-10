# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::ApplicationSerializer do
  describe ".serialize" do
    it "raises NotImplementedError on the base" do
      expect { described_class.serialize }.to raise_error(NotImplementedError)
    end
  end

  describe ".map_serialize" do
    let(:item_serializer) do
      Class.new(described_class) do
        def self.serialize(item)
          { id: item }
        end
      end
    end

    it "maps with a serializer class" do
      expect(described_class.map_serialize([1, 2], item_serializer)).to eq([{ id: 1 }, { id: 2 }])
    end

    it "maps with a block" do
      expect(described_class.map_serialize([1, 2]) { |n| n * 2 }).to eq([2, 4])
    end

    it "treats nil collection as empty" do
      expect(described_class.map_serialize(nil, item_serializer)).to eq([])
    end
  end

  describe ".iso8601" do
    it "returns nil for nil" do
      expect(described_class.iso8601(nil)).to be_nil
    end

    it "formats time" do
      expect(described_class.iso8601(Time.utc(2026, 1, 2, 3, 4, 5))).to eq("2026-01-02T03:04:05Z")
    end
  end
end
