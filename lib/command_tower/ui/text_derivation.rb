# frozen_string_literal: true

module CommandTower
  module UI
    # Derives plain text from a node tree for `textFallback`, logs and
    # text-only channels.
    #
    # - text and banner: spans concatenated (banner title first, on its own line)
    # - time: TimeFormatter with the zone label always shown
    # - component: its fallback tree
    # - key_value: "Label: value" lines; stat_tile: "label: value"
    # - code: excluded (design P16: a code value never reaches derived text)
    # - containers (stack, card, facts): non-empty children, one per line
    #
    # Any node can be derived alone, so `facts` works without its document.
    module TextDerivation
      HANDLERS = {
        Nodes::Container => :container_text,
        Nodes::Text => :text_text,
        Nodes::Banner => :banner_text,
        Nodes::Instant => :instant_text,
        Nodes::KeyValue => :key_value_text,
        Nodes::Component => :component_text,
        Nodes::StatTile => :stat_tile_text,
        Nodes::Badge => :label_text,
        Nodes::Button => :label_text,
        Nodes::Image => :image_text
      }.freeze

      class << self
        def call(node)
          _, handler = HANDLERS.find { |klass, _| node.is_a?(klass) }
          handler ? send(handler, node) : "" # divider, avatar, code
        end

        private

        def container_text(node)
          lines(node.children.map { |child| call(child) })
        end

        def text_text(node)
          spans_text(node.spans)
        end

        def banner_text(node)
          lines([node.title, spans_text(node.spans)])
        end

        def instant_text(node)
          TimeFormatter.call(at: node.at, zone: node.zone, format: node.format, label: :always)
        end

        def key_value_text(node)
          lines(node.items.map { |item| item_text(item) })
        end

        def component_text(node)
          call(node.fallback)
        end

        def stat_tile_text(node)
          "#{node.label}: #{node.value}"
        end

        def label_text(node)
          node.label.to_s
        end

        def image_text(node)
          node.decorative ? "" : node.alt.to_s
        end

        def item_text(item)
          value = item.value.is_a?(Nodes::Instant) ? instant_text(item.value) : item.value.to_s
          item.label.to_s.empty? ? value : "#{item.label}: #{value}"
        end

        def spans_text(spans)
          spans.map(&:text).join
        end

        def lines(parts)
          parts.map(&:to_s).reject(&:empty?).join("\n")
        end
      end
    end
  end
end
