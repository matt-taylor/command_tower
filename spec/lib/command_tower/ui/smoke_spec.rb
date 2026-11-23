# frozen_string_literal: true

# The brief's "console check" as an example: build a document by hand from node
# objects, validate it and assert its wire form.
RSpec.describe CommandTower::UI::Document, "smoke", :aggregate_failures do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  let(:nodes) { CommandTower::UI::Nodes }
  let(:header) do
    nodes::Stack.new(gap: :xs, children: [
      nodes::Text.new(variant: :heading_m, spans: ["Class canceled"]),
      nodes::Text.new(variant: :subtitle, text_tone: :secondary, spans: ["Thursday evening"])
    ])
  end
  let(:body) do
    nodes::KeyValue.new(items: [
      { icon: "calendar", label: "When",
        value: nodes::Instant.new(at: "2025-12-04T14:00:00Z", zone: "America/Los_Angeles", format: :short) },
      { label: "Where", value: "Studio B" }
    ])
  end
  let(:root) do
    cta = nodes::Button.new(
      label: "View classes", variant: :primary, action: nodes::Action::Navigate.new(path: "/classes")
    )
    nodes::Card.new(surface: :raised, padding: :xl, children: [
      nodes::Stack.new(gap: :lg, children: [header, body, nodes::Divider.new, cta])
    ])
  end
  let(:document) { described_class.new(root: root, text_fallback: "Class canceled. Thursday evening.") }

  it "validates" do
    expect(document.validate!).to equal(document)
  end

  it "emits the catalog 2 envelope" do
    expect(document.as_json).to include(
      "schema" => "ui_document", "catalog" => 2, "textFallback" => "Class canceled. Thursday evening."
    )
  end

  it "emits the nested wire shape" do # rubocop:disable RSpec/ExampleLength
    expect(document.as_json["root"]).to eq(
      "type" => "card", "surface" => "raised", "padding" => "xl",
      "children" => [
        { "type" => "stack", "gap" => "lg", "children" => [
          { "type" => "stack", "gap" => "xs", "children" => [
            { "type" => "text", "variant" => "heading_m", "textTone" => "primary",
              "spans" => [{ "type" => "text", "text" => "Class canceled" }] },
            { "type" => "text", "variant" => "subtitle", "textTone" => "secondary",
              "spans" => [{ "type" => "text", "text" => "Thursday evening" }] }
          ] },
          { "type" => "key_value", "items" => [
            { "icon" => "calendar", "label" => "When",
              "value" => { "type" => "time", "at" => "2025-12-04T14:00:00Z", "zone" => "America/Los_Angeles",
                           "format" => "short", "label" => "auto", "variant" => "body", "textTone" => "primary" } },
            { "label" => "Where", "value" => "Studio B" }
          ] },
          { "type" => "divider" },
          { "type" => "button", "label" => "View classes", "variant" => "primary",
            "action" => { "type" => "navigate", "destination" => { "kind" => "internal", "path" => "/classes" } } }
        ] }
      ]
    )
  end

  it "serializes to JSON within the size limit" do
    expect(JSON.generate(document.as_json).bytesize).to be < CommandTower::UI::Limits::MAX_BYTES
  end
end
