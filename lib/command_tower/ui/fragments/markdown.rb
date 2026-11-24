# frozen_string_literal: true

require "kramdown"
require "command_tower/ui/markdown_subset/segment"
require "command_tower/ui/markdown_subset/inline"
require "command_tower/ui/markdown_subset/walker"
require "command_tower/ui/markdown_subset/chunker"

module CommandTower
  module UI
    module Fragments
      # Renders an announcement body (a markdown subset) as catalog primitives.
      # The kramdown AST is walked against an allowlist (MarkdownSubset::Walker
      # and Inline): anything not named there is reduced to its plain text or
      # dropped. Raw HTML never reaches the document. Rules: design ux/states.md
      # section 6, G11 and G12; the supported subset is listed in docs/ui.md.
      #
      #   d.fragment(Fragments::Markdown, source: "Hello **there**, see [classes](/classes).")
      #
      # Emits one `stack` of `text` nodes (nothing when the source has no
      # renderable content). Long paragraphs are split at word boundaries. Output
      # beyond `node_budget` nodes is cut and ends with a "…" paragraph.
      class Markdown < Fragment
        DEFAULT_NODE_BUDGET = 150
        # The root stack and the closing ellipsis paragraph (text plus one span).
        RESERVED_NODES = 3
        ELLIPSIS = "…"

        attribute :source, :string
        attribute :node_budget, :integer, default: DEFAULT_NODE_BUDGET

        validates :source, presence: true
        validates :node_budget, numericality: { only_integer: true, greater_than: RESERVED_NODES }

        def compose(builder)
          blocks = fit_budget(chunked(MarkdownSubset::Walker.call(parse)))
          return if blocks.empty?

          builder.stack(gap: :md) { |stack| groups(blocks).each { |group| emit_group(stack, group) } }
        end

        private

        def parse
          Kramdown::Document.new(source, input: "kramdown", parse_block_html: true, parse_span_html: true,
                                         html_to_native: false, auto_ids: false).root
        end

        def chunked(blocks)
          blocks.flat_map do |block|
            MarkdownSubset::Chunker.call(block.segments).map do |run|
              MarkdownSubset::Block.new(block.variant, run, block.list_id)
            end
          end
        end

        # Keeps blocks while the node budget allows, then ends with "…".
        def fit_budget(blocks)
          seen = []
          used = 0
          kept = blocks.take_while do |block|
            used += cost(block, seen)
            used <= node_budget - RESERVED_NODES
          end
          return blocks if kept.length == blocks.length

          log_truncation(kept.length, blocks.length)
          kept + [MarkdownSubset::Block.new("body", [MarkdownSubset::Segment.new(ELLIPSIS)])]
        end

        # Nodes a block adds: its text, its spans, and the list stack on a list's first item.
        def cost(block, seen)
          new_list = block.list_id && seen.exclude?(block.list_id)
          seen << block.list_id if new_list
          1 + block.segments.length + (new_list ? 1 : 0)
        end

        # Counts only, never content.
        def log_truncation(kept, total)
          Rails.logger.warn do
            "[CommandTower::UI::Fragments::Markdown] cut at node budget (#{kept} of #{total} paragraphs kept)"
          end
        end

        # List items share one group; every other block is its own group.
        def groups(blocks)
          blocks.slice_when { |a, b| a.list_id.nil? || a.list_id != b.list_id }.to_a
        end

        def emit_group(stack, group)
          if group.first.list_id
            stack.stack(gap: :xs) { |inner| group.each { |block| emit_text(inner, block) } }
          else
            emit_text(stack, group.first)
          end
        end

        def emit_text(builder, block)
          spans = block.segments.map { |segment| span_for(builder, segment) }
          options = { variant: block.variant.to_sym }
          options[:text_tone] = :secondary if block.variant == "subtitle"
          builder.text(*spans, **options)
        end

        def span_for(builder, segment)
          if segment.href
            builder.link(segment.text, action: link_action(builder, segment.href))
          elsif segment.strong
            builder.strong(segment.text)
          else
            segment.text
          end
        end

        def link_action(builder, href)
          Hardening.internal_path?(href) ? builder.navigate(path: href) : builder.navigate(href:)
        end
      end
    end
  end
end
