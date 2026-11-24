# frozen_string_literal: true

module CommandTower
  module UI
    module MarkdownSubset
      # Allowlist walk over block-level kramdown elements. Returns Blocks;
      # elements not listed in HANDLERS (hr, blank, comments, ...) are dropped.
      class Walker
        HEADING_VARIANTS = { 1 => "title", 2 => "title", 3 => "subtitle" }.freeze
        LISTS = %i[ul ol].freeze
        HANDLERS = {
          p: :paragraph_block, header: :header_block, ul: :list_blocks, ol: :list_blocks,
          codeblock: :code_block, table: :table_blocks, html_element: :html_block, raw: :raw_block,
          blockquote: :container_blocks, dl: :container_blocks, dt: :container_blocks,
          dd: :container_blocks, li: :container_blocks
        }.freeze

        def self.call(root)
          new.call(root)
        end

        def initialize
          @list_id = 0
        end

        def call(root)
          blocks_of(root.children)
        end

        private

        def blocks_of(children)
          children.chunk { |child| Inline.inline?(child) }.flat_map do |inline, group|
            inline ? text_block("body", group) : group.flat_map { |child| block_for(child) }
          end
        end

        def block_for(element)
          handler = HANDLERS[element.type]
          handler ? send(handler, element) : []
        end

        def text_block(variant, children)
          segments = Inline.segments(children)
          blank?(segments) ? [] : [Block.new(variant, segments)]
        end

        def paragraph_block(element)
          text_block("body", element.children)
        end

        def header_block(element)
          text_block(HEADING_VARIANTS.fetch(element.options[:level].to_i, "body"), element.children)
        end

        def container_blocks(element)
          blocks_of(element.children)
        end

        def html_block(element)
          Inline::DROPPED_HTML.include?(element.value) ? [] : blocks_of(element.children)
        end

        def code_block(element)
          literal_block(element.value.to_s.chomp)
        end

        # With parse_block_html the body is parsed; :raw is what is left over.
        def raw_block(element)
          literal_block(strip_tags(element.value.to_s).strip)
        end

        def literal_block(text)
          text.strip.empty? ? [] : [Block.new("body", [Segment.new(text)])]
        end

        def strip_tags(html)
          html.gsub(%r{<(script|style)\b[^>]*>.*?</\1\s*>}mi, "").gsub(/<[^>]*>/m, "")
        end

        # One paragraph per row, cells joined by a middle dot.
        def table_blocks(table)
          rows(table).flat_map do |row|
            cells = row.children.map { |cell| Inline.plain_text(cell).strip }.reject(&:empty?)
            cells.empty? ? [] : literal_block(cells.join(" · "))
          end
        end

        def rows(element)
          element.children.flat_map { |child| child.type == :tr ? [child] : rows(child) }
        end

        def list_blocks(list)
          @list_id += 1
          id = @list_id
          list_items(list).map { |prefix, segments| Block.new("body", [Segment.new(prefix)] + segments, id) }
        end

        # Nested lists are flattened to one level. Returns [prefix, segments] pairs.
        def list_items(list)
          list.children.select { |child| child.type == :li }.each_with_index.flat_map do |item, index|
            item_entries(item, item_prefix(list, index))
          end
        end

        def item_entries(item, prefix)
          nested, own = item.children.partition { |child| LISTS.include?(child.type) }
          segments = item_segments(own)
          head = blank?(segments) ? [] : [[prefix, segments]]
          head + nested.flat_map { |inner| list_items(inner) }
        end

        def item_prefix(list, index)
          list.type == :ol ? "#{index + 1}. " : "• "
        end

        def item_segments(children)
          blocks_of(children).map(&:segments).each_with_index.flat_map do |segments, index|
            index.zero? ? segments : [Segment.new(" ")] + segments
          end
        end

        def blank?(segments)
          segments.all? { |segment| segment.text.strip.empty? }
        end
      end
    end
  end
end
