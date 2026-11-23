# frozen_string_literal: true

module CommandTower
  module UI
    # Maps a catalog-2 UI document to `inbox_document_v1` blocks for catalog-1
    # clients. Not wired into any caller yet.
    #
    # Output is emitted through the real `InboxDocument.compose` Builder
    # (resolved at call time, so lib/ui keeps no load-time dependency on
    # Messaging). The Builder owns the block rules; this mapping adds the
    # narrower external-link allowlist (https, mailto, tel) the Builder lacks.
    #
    # - text: paragraph (spans flattened, links lose their action)
    # - button: cta with a typed destination; dropped when the destination
    #   fails the allowlist
    # - time: instant
    # - component whose key is in `legacy_presentation_keys`: presentation;
    #   any other component maps its fallback tree
    # - stack, card, facts: children mapped in order
    # - banner, key_value, stat_tile, badge, image: derived-text paragraph
    # - divider, avatar and code: dropped (a code value never reaches output)
    module LegacyMapping
      DERIVED_TEXT_NODES = [Nodes::Banner, Nodes::KeyValue, Nodes::StatTile, Nodes::Badge, Nodes::Image].freeze

      class << self
        def call(document, legacy_presentation_keys: [])
          keys = Array(legacy_presentation_keys).map(&:to_s)
          Messaging::Rendering::InboxDocument.compose do |builder|
            map_node(document.root, builder, keys)
          end
        end

        private

        def map_node(node, builder, keys)
          case node
          when Nodes::Container then node.children.each { |child| map_node(child, builder, keys) }
          when Nodes::Text, *DERIVED_TEXT_NODES then builder.paragraph(TextDerivation.call(node))
          when Nodes::Button then map_button(node, builder)
          when Nodes::Instant then builder.instant(node.at)
          when Nodes::Component then map_component(node, builder, keys)
          end
        end

        def map_button(node, builder)
          action = node.action
          return unless action.is_a?(Nodes::Action::Navigate)

          if action.path
            builder.cta(node.label, path: action.path) if Hardening.internal_path?(action.path)
          elsif action.href && Hardening.external_href_code(action.href).nil?
            builder.cta(node.label, href: action.href)
          end
        end

        def map_component(node, builder, keys)
          if keys.include?(node.key)
            builder.presentation(node.key, variant: node.variant)
          else
            map_node(node.fallback, builder, keys)
          end
        end
      end
    end
  end
end
