# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Span, :aggregate_failures do
  it "serializes a text span" do
    expect(described_class.new(text: "Hi").as_json).to eq("type" => "text", "text" => "Hi")
  end

  it "serializes a strong span" do
    expect(described_class.new(text: "Hi", strong: true).as_json)
      .to eq("type" => "text", "text" => "Hi", "strong" => true)
  end

  it "serializes a link span with its navigate action" do
    expect(described_class.link("Open", action: UiSpecHelpers.navigate("/x")).as_json).to eq(
      "type" => "link", "text" => "Open",
      "action" => { "type" => "navigate", "destination" => { "kind" => "internal", "path" => "/x" } }
    )
  end

  it "requires text" do
    expect(UiSpecHelpers.error_pairs(described_class.new(text: ""))).to eq([%i[text blank]])
  end

  it "rejects unknown types" do
    expect(UiSpecHelpers.error_pairs(described_class.new(type: "image", text: "x"))).to eq([%i[type inclusion]])
  end

  it "requires an action on links" do
    expect(UiSpecHelpers.error_pairs(described_class.new(type: "link", text: "x"))).to eq([%i[action invalid_action]])
  end

  it "forbids an action on text spans" do
    expect(UiSpecHelpers.error_pairs(described_class.new(text: "x", action: UiSpecHelpers.navigate)))
      .to eq([%i[action not_allowed]])
  end

  context "with a bad link destination" do
    let(:root) do
      bad_link = described_class.link("Go", action: UiSpecHelpers.navigate("//evil.com"))
      CommandTower::UI::Nodes::Text.new(spans: [bad_link])
    end

    it "reports it at the nested path" do
      expect(UiSpecHelpers.document(root).validation_errors)
        .to eq([{ path: "root.spans[0].action.path", code: "invalid_path" }])
    end
  end

  it "rejects strings over the length cap" do
    expect(UiSpecHelpers.error_pairs(described_class.new(text: "a" * 2_001))).to eq([%i[text too_long]])
  end
end
