# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::NoticeFrame, :aggregate_failures do
  let(:inputs) { { title: "Heads up", tone: :warning, body: %w[One Two] } }
  let(:root) { FragmentTree.root { |d| d.fragment(described_class, **inputs) } }
  let(:inner) { root["children"].first }

  it "emits a tinted card" do
    expect(root).to include("type" => "card", "surface" => "tinted", "tone" => "warning", "padding" => "lg")
  end

  it "stacks the title above the body paragraphs" do
    expect(inner).to include("type" => "stack", "gap" => "sm")
    expect(inner["children"].pluck("variant")).to eq(%w[heading_m body body])
  end

  it "emits only primitives and no button" do
    expect(FragmentTree.non_primitive_types(root)).to be_empty
    expect(FragmentTree.types(root)).not_to include("button")
  end

  context "with an unknown tone" do
    let(:inputs) { { title: "t", tone: "loud" } }

    it "raises InvalidFragmentError" do
      expect { described_class.new(**inputs) }.to raise_error(CommandTower::UI::InvalidFragmentError, /tone:inclusion/)
    end
  end
end
