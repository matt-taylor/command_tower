# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::Header, :aggregate_failures do
  let(:inputs) do
    { title: "Canceled", subtitle: "Studio B", badge_label: "Canceled", badge_tone: :danger,
      avatar: { initials: "SB" } }
  end
  let(:root) { FragmentTree.root { |d| d.fragment(described_class, **inputs) } }

  it "emits a vertical stack of avatar, badge and a title stack" do
    expect(root).to include("type" => "stack", "gap" => "sm", "align" => "start")
    expect(root["children"].pluck("type")).to eq(%w[avatar badge stack])
    expect(root["children"].first).to include("size" => "md", "initials" => "SB")
  end

  it "stacks the title above the subtitle" do
    expect(root["children"].last).to include("gap" => "xs")
    expect(root["children"].last["children"].pluck("variant")).to eq(%w[heading_m subtitle])
  end

  it "tones the subtitle secondary and leaves the title at the default tone" do
    expect(root["children"].last["children"].pluck("textTone")).to eq(%w[primary secondary])
  end

  it "emits only primitives" do
    expect(FragmentTree.non_primitive_types(root)).to be_empty
  end

  context "with only a title" do
    let(:inputs) { { title: "Only" } }

    it "omits the avatar, badge and subtitle" do
      expect(root["children"].pluck("type")).to eq(%w[stack])
      expect(root["children"].first["children"].pluck("variant")).to eq(%w[heading_m])
    end
  end

  context "without a title" do
    let(:inputs) { { title: "" } }

    it "raises InvalidFragmentError" do
      expect { described_class.new(**inputs) }.to raise_error(CommandTower::UI::InvalidFragmentError, /title:blank/)
    end
  end
end
