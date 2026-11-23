# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::CtaGroup, :aggregate_failures do
  let(:action) { CommandTower::UI::Builder.new.navigate(path: "/classes") }
  let(:buttons) do
    [
      { label: "Later", action: action },
      { label: "Go", action: action, variant: :primary },
      { label: "Skip", action: action, variant: :ghost }
    ]
  end
  let(:root) { FragmentTree.root { |d| d.fragment(described_class, buttons: buttons) } }
  let(:error) { CommandTower::UI::InvalidFragmentError }

  it "emits a stack with the primary first, then the secondaries" do
    expect(root).to include("type" => "stack", "gap" => "sm")
    expect(root["children"].map { |button| [button["label"], button["variant"]] })
      .to eq([%w[Go primary], %w[Later secondary], %w[Skip ghost]])
  end

  it "emits only primitives" do
    expect(FragmentTree.non_primitive_types(root)).to be_empty
  end

  context "with a second primary" do
    let(:buttons) do
      [{ label: "A", action: action, variant: :primary }, { label: "B", action: action, variant: "primary" }]
    end

    it "raises InvalidFragmentError" do
      expect { described_class.new(buttons: buttons) }.to raise_error(error, /buttons:too_many_primaries/)
    end
  end

  context "with more than two secondaries" do
    let(:buttons) { Array.new(3) { |index| { label: "B#{index}", action: action } } }

    it "raises InvalidFragmentError" do
      expect { described_class.new(buttons: buttons) }.to raise_error(error, /buttons:too_many_secondaries/)
    end
  end

  context "with no buttons" do
    let(:buttons) { [] }

    it "raises InvalidFragmentError" do
      expect { described_class.new(buttons: buttons) }.to raise_error(error, /buttons:invalid/)
    end
  end
end
