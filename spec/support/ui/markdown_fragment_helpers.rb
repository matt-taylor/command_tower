# frozen_string_literal: true

# Helpers for the Markdown fragment spec: render a source to the wire tree and
# read its text nodes and spans.
module MarkdownFragmentHelpers
  def render(source, **)
    FragmentTree.root { |d| d.fragment(CommandTower::UI::Fragments::Markdown, source:, **) }
  end

  def texts(tree)
    tree["children"].flat_map { |node| node["type"] == "stack" ? node["children"] : [node] }
  end

  def plain(node)
    node["spans"].pluck("text").join
  end

  def spans_of(source)
    texts(render(source)).flat_map { |node| node["spans"] }
  end

  def link_actions(source)
    spans_of(source).select { |span| span["type"] == "link" }.pluck("action")
  end
end
