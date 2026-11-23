# frozen_string_literal: true

# Helpers for the fragment specs: build a validated document from a block and
# walk its wire tree.
module FragmentTree
  PRIMITIVE_TYPES = %w[stack card facts divider text key_value badge button image banner avatar stat_tile code
                       component].freeze
  # Actions carry a `type` too but are not nodes.
  ACTION_TYPES = %w[navigate].freeze

  # The wire `root` of a validated document built by the block.
  def self.root(&)
    CommandTower::UI.document(text_fallback: "x", &).validate!.as_json["root"]
  end

  # Every `type` found anywhere in the tree.
  def self.types(node, found = [])
    case node
    when Hash
      found << node["type"] if node["type"]
      node.each_value { |value| types(value, found) }
    when Array
      node.each { |value| types(value, found) }
    end
    found
  end

  # Types that are neither a catalog primitive nor an action.
  def self.non_primitive_types(node)
    types(node) - PRIMITIVE_TYPES - ACTION_TYPES
  end
end

# A host-style Facts subclass for the Facts spec.
module SampleHostUI
  class ClassFacts < CommandTower::UI::Fragments::Facts
    def compose(builder, metadata:)
      builder.text(metadata.fetch(:title), variant: :title)
      builder.key_value { |rows| rows.item "Where", metadata.fetch(:where) }
      builder.badge("Open", tone: :success)
    end
  end
end
