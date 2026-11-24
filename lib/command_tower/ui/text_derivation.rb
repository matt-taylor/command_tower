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
        # `user_zone` is the zone a `zone: "user"` time resolves to.
        def call(node, user_zone: CommandTower.config.ui.default_zone)
          _, handler = HANDLERS.find { |klass, _| node.is_a?(klass) }
          handler ? send(handler, node, user_zone) : "" # divider, avatar, code
        end

        private

        def container_text(node, user_zone)
          lines(node.children.map { |child| call(child, user_zone:) })
        end

        def text_text(node, _user_zone)
          spans_text(node.spans)
        end

        def banner_text(node, _user_zone)
          lines([node.title, spans_text(node.spans)])
        end

        def instant_text(node, user_zone)
          TimeFormatter.call(at: node.at, zone: node.zone, format: node.format, label: :always, user_zone:)
        end

        def key_value_text(node, user_zone)
          lines(node.items.map { |item| item_text(item, user_zone) })
        end

        def component_text(node, user_zone)
          call(node.fallback, user_zone:)
        end

        def stat_tile_text(node, _user_zone)
          "#{node.label}: #{node.value}"
        end

        def label_text(node, _user_zone)
          node.label.to_s
        end

        def image_text(node, _user_zone)
          node.decorative ? "" : node.alt.to_s
        end

        def item_text(item, user_zone)
          value = item.value.is_a?(Nodes::Instant) ? instant_text(item.value, user_zone) : item.value.to_s
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
