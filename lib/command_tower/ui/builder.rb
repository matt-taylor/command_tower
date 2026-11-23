# frozen_string_literal: true

require "command_tower/ui/builder/frame"
require "command_tower/ui/builder/token_resolver"
require "command_tower/ui/builder/item_builder"

module CommandTower
  module UI
    # Block DSL that builds node objects. One method per catalog primitive.
    #
    #   UI.document(text_fallback: "Class canceled") do |d|
    #     d.stack(gap: :lg) do |s|
    #       s.text("Class ", d.strong("canceled"), variant: :heading_m)
    #       s.key_value { |kv| kv.item "When", kv.time(at: starts_at, zone: "America/Los_Angeles") }
    #       s.button "View classes", action: d.navigate(path: "/classes"), variant: :primary
    #     end
    #   end
    #
    # Block forms yield the builder itself; children are collected in order.
    # `time` inside `key_value` returns the node for use as an item value
    # instead of adding it as a child.
    #
    # Token arguments (gap, tone, variant, ...) accept symbols or strings; see
    # TokenResolver for the unknown-token policy.
    #
    # Out of scope: markdown and any registry (design D3).
    class Builder
      def initialize
        @frames = [Frame.new("root", :root, [])]
      end

      # Nodes added at the top level (a document wants exactly one).
      def roots
        @frames.first.nodes
      end

      def stack(gap: nil, align: nil, &)
        container(:stack, Nodes::Stack, { gap:, align: }, &)
      end

      def card(surface: nil, tone: nil, padding: nil, &)
        container(:card, Nodes::Card, { surface:, tone:, padding: }, &)
      end

      def facts(&)
        container(:facts, Nodes::Facts, {}, &)
      end

      def divider
        leaf(:divider, Nodes::Divider, {})
      end

      def text(*spans, variant: nil, text_tone: nil, max_lines: nil)
        leaf(:text, Nodes::Text, { variant:, text_tone:, max_lines:, spans: spans.flatten })
      end

      def time(**)
        place(build_time(@frames.last.next_path, **))
      end

      def key_value(&)
        node_path = @frames.last.next_path
        rows = ItemBuilder.new(self, node_path)
        yield rows
        place(build(:key_value, Nodes::KeyValue, node_path, { items: rows.items }))
      end

      def badge(label, tone: nil)
        leaf(:badge, Nodes::Badge, { label:, tone: })
      end

      def button(label, action:, variant: nil)
        leaf(:button, Nodes::Button, { label:, action:, variant: })
      end

      def image(src:, aspect:, **options)
        leaf(:image, Nodes::Image, { src:, aspect: }.merge(options))
      end

      def banner(*spans, title: nil, tone: nil)
        leaf(:banner, Nodes::Banner, { title:, tone:, spans: spans.flatten })
      end

      def avatar(src: nil, initials: nil, alt: nil, size: nil)
        leaf(:avatar, Nodes::Avatar, { src:, initials:, alt:, size: })
      end

      def stat_tile(value:, label:, tone: nil, icon: nil)
        leaf(:stat_tile, Nodes::StatTile, { value:, label:, tone:, icon: })
      end

      def code(value:, label:, format:)
        leaf(:code, Nodes::Code, { value:, label:, format: })
      end

      # `fallback` is built by the block, which must add exactly one node.
      def component(key:, variant: nil, data: {}, &)
        node_path = @frames.last.next_path
        fallback = collect(Frame.new(node_path, :fallback, []), &).first
        place(build(:component, Nodes::Component, node_path, { key:, variant:, data:, fallback: }))
      end

      # Expands a fragment into primitives at this point. A fragment is any
      # class whose instances respond to `compose(builder)`.
      def fragment(klass, **args)
        klass.new(**args).compose(self)
      end

      def navigate(path: nil, href: nil)
        Nodes::Action::Navigate.new(path:, href:)
      end

      def strong(text)
        Nodes::Span.new(text:, strong: true)
      end

      def link(text, action:)
        Nodes::Span.link(text, action:)
      end

      # Builds an Instant without placing it (also used by ItemBuilder#time).
      def build_time(node_path, **attributes)
        attributes = { zone: CommandTower.config.ui.default_zone }.merge(attributes)
        build(:time, Nodes::Instant, node_path, attributes)
      end

      private

      def container(type, klass, attributes, &)
        node_path = @frames.last.next_path
        children = collect(Frame.new(node_path, :children, []), &)
        place(build(type, klass, node_path, attributes.merge(children:)))
      end

      def leaf(type, klass, attributes)
        place(build(type, klass, @frames.last.next_path, attributes))
      end

      def place(node)
        @frames.last.nodes << node
        node
      end

      def collect(frame)
        @frames.push(frame)
        yield self
        frame.nodes
      ensure
        @frames.pop
      end

      def build(type, klass, node_path, attributes)
        klass.new(**TokenResolver.call(type, node_path, attributes).compact)
      end
    end
  end
end
