# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Button, :aggregate_failures do
  let(:unsafe_action) { CommandTower::UI::Nodes::Action::Navigate.new(href: "javascript:1") }

  it "serializes with its navigate action" do
    expect(described_class.new(label: "Open", variant: :primary, action: UiSpecHelpers.navigate("/x")).as_json).to eq(
      "type" => "button", "label" => "Open", "variant" => "primary",
      "action" => { "type" => "navigate", "destination" => { "kind" => "internal", "path" => "/x" } }
    )
  end

  CommandTower::UI::Tokens::BUTTON_VARIANT.each do |variant|
    it "accepts variant #{variant}" do
      expect(
        UiSpecHelpers.error_pairs(described_class.new(label: "x", variant: variant, action: UiSpecHelpers.navigate))
      ).to eq([])
    end
  end

  it "requires label, known variant and a navigate action" do
    expect(UiSpecHelpers.error_pairs(described_class.new(label: "", variant: "huge")))
      .to contain_exactly(%i[label blank], %i[variant inclusion], %i[action invalid_action])
  end

  it "reports an unsafe external action at the nested path" do
    expect(UiSpecHelpers.document(described_class.new(label: "Go", action: unsafe_action)).validation_errors)
      .to eq([{ path: "root.action.href", code: "unsafe_scheme" }])
  end
end
