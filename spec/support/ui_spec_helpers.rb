# frozen_string_literal: true

require "json"

# Helpers for CommandTower::UI specs. Example groups cannot define `def`
# helpers (test standards guard), so shared logic lives here.
module UiSpecHelpers
  WIRE_HARDENING_PATH = File.expand_path("../fixtures/ui/wire_hardening.json", __dir__)

  module_function

  def wire_hardening
    @wire_hardening ||= JSON.parse(File.read(WIRE_HARDENING_PATH))
  end

  # [[attribute, type], ...] after running validations.
  def error_pairs(object)
    object.valid?
    object.errors.map { |error| [error.attribute, error.type] }
  end

  def navigate(path = "/inbox")
    CommandTower::UI::Nodes::Action::Navigate.new(path:)
  end

  def text(content = "Hello", **attrs)
    CommandTower::UI::Nodes::Text.new(spans: [content], **attrs)
  end

  def divider
    CommandTower::UI::Nodes::Divider.new
  end

  def button(action, variant: "secondary")
    CommandTower::UI::Nodes::Button.new(label: "Go", action:, variant:)
  end

  def text_and_https_button
    stack(text, external_button("https://example.com/a"))
  end

  def mail_and_tel_buttons
    stack(external_button("mailto:a@example.com"), external_button("tel:+15551234567"))
  end

  def primary_https_button_stack
    stack(external_button("https://example.com", variant: "primary"))
  end

  def primary_internal_stack
    stack(button(navigate, variant: "primary"))
  end

  def internal_link_text
    CommandTower::UI::Nodes::Text.new(spans: [CommandTower::UI::Nodes::Span.link("See", action: navigate)])
  end

  def external_button(href, variant: "secondary")
    button(external_navigate(href), variant:)
  end

  def external_navigate(href)
    CommandTower::UI::Nodes::Action::Navigate.new(href:)
  end

  def errors_for(root, profile:)
    document(root).validation_errors(profile:)
  end

  def stack(*children, **attrs)
    CommandTower::UI::Nodes::Stack.new(children:, **attrs)
  end

  def document(root, text_fallback: "Fallback")
    CommandTower::UI::Document.new(root:, text_fallback:)
  end

  # Builds the root node described by a wire_hardening.json limit case "build".
  def limit_root(build)
    send("limit_#{build['kind']}", build)
  end

  def limit_flat_stack(build)
    stack(*Array.new(build["nodes"] - 1) { divider })
  end

  def limit_nested_stacks(build)
    Array.new(build["depth"]).inject(nil) { |inner, _| inner ? stack(inner) : stack }
  end

  def limit_long_text(build)
    text("a" * build["length"])
  end

  def limit_spans(build)
    CommandTower::UI::Nodes::Text.new(spans: Array.new(build["count"]) { "a" })
  end

  def limit_key_value_items(build)
    items = Array.new(build["count"]) { { label: "Label", value: "Value" } }
    CommandTower::UI::Nodes::KeyValue.new(items:)
  end

  # Derived text of the single root a UI.document block builds.
  def derive_text(&)
    CommandTower::UI::TextDerivation.call(CommandTower::UI.document(text_fallback: "x", &).root)
  end

  # Blocks LegacyMapping emits for the document a UI.document block builds.
  def legacy_blocks(keys: [], &)
    document = CommandTower::UI.document(text_fallback: "x", &)
    CommandTower::UI::LegacyMapping.call(document, legacy_presentation_keys: keys).blocks
  end

  def limit_facts_children(build)
    CommandTower::UI::Nodes::Facts.new(children: Array.new(build["count"]) { divider })
  end

  def limit_fat_texts(build)
    stack(*Array.new(build["count"]) { text("a" * build["length"]) })
  end

  def limit_components(build)
    stack(*Array.new(build["count"]) do
      CommandTower::UI::Nodes::Component.new(key: "demo.widget", fallback: text("Fallback"))
    end)
  end

  def limit_primary_buttons(build)
    stack(*Array.new(build["count"]) do
      CommandTower::UI::Nodes::Button.new(label: "Go", variant: "primary", action: navigate)
    end)
  end
end
