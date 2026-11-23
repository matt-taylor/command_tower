# frozen_string_literal: true

require "json"

# Shared document fixtures for the UI foundation (design ux/states.md section 2).
# The definitions live in the dummy app (not packaged). `rake command_tower:ui:fixtures`
# writes one JSON file per fixture to spec/fixtures/ui/documents/<key>.json, which the
# frontend and email renderers consume; a spec checks the committed files stay in sync.
#
# Every fixture is a composer whose root is a raised card (padding xl) holding a
# stack (gap lg) of the content the definition block adds.
module UiFixtures
  OUTPUT_DIR = File.expand_path("../../spec/fixtures/ui/documents", __dir__)

  # A composer whose content comes from a block.
  class Fixture < CommandTower::UI::Composer
    def initialize(fallback: nil, &content)
      super()
      @fallback = fallback
      @content = content
    end

    def compose(builder, **)
      builder.card(surface: :raised, padding: :xl) do |card|
        card.stack(gap: :lg) { |stack| @content.call(stack) }
      end
    end

    # A `code` node derives no text (its value is secret), so such fixtures pass their own.
    def text_fallback(_root, **)
      @fallback
    end
  end

  class << self
    def define(key, fallback: nil, &)
      registry[key.to_s] = Fixture.new(fallback:, &)
    end

    def keys
      registry.keys
    end

    def document(key)
      registry.fetch(key.to_s).call
    end

    # Pretty-printed JSON with deeply sorted keys and a trailing newline.
    def json(key)
      "#{JSON.pretty_generate(sort_keys(document(key).as_json))}\n"
    end

    def path(key)
      File.join(OUTPUT_DIR, "#{key}.json")
    end

    def write_all
      FileUtils.mkdir_p(OUTPUT_DIR)
      keys.each { |key| File.write(path(key), json(key)) }
    end

    private

    def registry
      @registry ||= {}
    end

    def sort_keys(value)
      case value
      when Hash then value.sort_by { |key, _| key.to_s }.to_h { |key, inner| [key, sort_keys(inner)] }
      when Array then value.map { |inner| sort_keys(inner) }
      else value
      end
    end
  end
end

require_relative "ui_fixtures/component_fixtures"
require_relative "ui_fixtures/fragment_fixtures"
