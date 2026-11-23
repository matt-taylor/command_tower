# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragment, :aggregate_failures do
  let(:ui) { CommandTower::UI }

  let(:document) do
    ui.document(text_fallback: "x") do |d|
      d.stack { |s| s.fragment(SampleHostUI::FactRow, label: "Where", value: "Studio B") }
    end
  end

  it "expands into primitives through the builder" do
    expect(document.as_json["root"]["children"]).to eq(
      [{ "type" => "key_value", "items" => [{ "label" => "Where", "value" => "Studio B" }] }]
    )
  end

  it "raises InvalidFragmentError with codes only for invalid inputs" do
    expect { SampleHostUI::FactRow.new(label: "Where", value: "") }
      .to raise_error(ui::InvalidFragmentError, "SampleHostUI::FactRow: invalid inputs (value:blank)")
  end

  it "raises InvalidFragmentError for unknown inputs" do
    expect { SampleHostUI::FactRow.new(label: "a", value: "b", extra: 1) }
      .to raise_error(ui::InvalidFragmentError, /unknown input extra/)
  end

  it "does not expose input values through inspect" do
    expect(SampleHostUI::FactRow.new(label: "secret", value: "v").inspect).not_to include("secret")
  end

  it "requires subclasses to implement compose" do
    expect { described_class.new.compose(ui::Builder.new) }.to raise_error(NotImplementedError)
  end
end
