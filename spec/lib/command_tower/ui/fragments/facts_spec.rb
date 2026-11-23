# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::Facts, :aggregate_failures do
  let(:metadata) { { title: "Yoga", where: "Studio B" } }
  let(:root) { FragmentTree.root { |d| d.stack { |s| SampleHostUI::ClassFacts.call(s, metadata: metadata) } } }
  let(:facts) { root["children"].first }

  it "yields exactly one facts node" do
    expect(FragmentTree.types(root).count("facts")).to eq(1)
    expect(facts["type"]).to eq("facts")
  end

  it "holds the subclass content" do
    expect(facts["children"].pluck("type")).to eq(%w[text key_value badge])
  end

  it "emits only primitives" do
    expect(FragmentTree.non_primitive_types(root)).to be_empty
  end

  it "requires subclasses to implement compose" do
    expect { described_class.call(CommandTower::UI::Builder.new, metadata: {}) }.to raise_error(NotImplementedError)
  end
end
