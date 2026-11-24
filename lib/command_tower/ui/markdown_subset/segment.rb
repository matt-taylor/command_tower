# frozen_string_literal: true

module CommandTower
  module UI
    # Helpers behind Fragments::Markdown: an allowlist walk over the kramdown
    # AST (Walker, Inline) and a splitter that keeps text within limits (Chunker).
    module MarkdownSubset
      # A run of text with one style. `href` is a vetted link target or nil.
      Segment = Struct.new(:text, :strong, :href)

      # One output paragraph. `list_id` groups the items of one list.
      Block = Struct.new(:variant, :segments, :list_id)
    end
  end
end
