# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Facts, :aggregate_failures do
  let(:divider) { UiSpecHelpers.divider }
  let(:nested_stack) { UiSpecHelpers.stack(*Array.new(100) { divider }) }

  it "serializes as a structural wrapper with children" do
    expect(described_class.new(children: [UiSpecHelpers.text("Hi")]).as_json.keys).to eq(%w[type children])
  end

  it "rejects non-node children" do
    expect(UiSpecHelpers.error_pairs(described_class.new(children: [1]))).to eq([%i[children invalid_child]])
  end

  it "reports too many descendants at the facts path" do
    expect(UiSpecHelpers.document(described_class.new(children: Array.new(101) { divider })).validation_errors)
      .to eq([{ path: "root", code: "too_many_facts_nodes" }])
  end

  it "counts nested descendants toward the facts cap" do
    expect(UiSpecHelpers.document(described_class.new(children: [nested_stack])).validation_errors)
      .to eq([{ path: "root", code: "too_many_facts_nodes" }])
  end
end
