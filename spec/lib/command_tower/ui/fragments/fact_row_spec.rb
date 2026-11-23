# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::FactRow, :aggregate_failures do
  let(:inputs) { { label: "Where", value: "Studio B", icon: "map-pin" } }
  let(:root) { FragmentTree.root { |d| d.fragment(described_class, **inputs) } }

  it "emits a key_value with one item" do
    expect(root).to eq(
      "type" => "key_value", "items" => [{ "icon" => "map-pin", "label" => "Where", "value" => "Studio B" }]
    )
  end

  it "emits only primitives" do
    expect(FragmentTree.non_primitive_types(root)).to be_empty
  end

  context "with a value only" do
    let(:inputs) { { value: "Studio B" } }

    it "omits the icon and label" do
      expect(root["items"]).to eq([{ "value" => "Studio B" }])
    end
  end

  context "without a value" do
    let(:inputs) { { label: "Where" } }

    it "raises InvalidFragmentError" do
      expect { described_class.new(**inputs) }.to raise_error(CommandTower::UI::InvalidFragmentError, /value:blank/)
    end
  end
end
