# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      # The plain-text part of an email: the derived text with link targets (design G13).
      # `TextDerivation` keeps only labels, so a plain-text reader could not follow a link or a
      # button. Here each link span and button also writes a `label: https://...` line after its
      # node's text. `textFallback` and channel slots stay on `TextDerivation`.
      #
      # `code` nodes are rejected by the renderer before this runs and `TextDerivation` excludes
      # them, so a code value never reaches the text part.
      module TextPart
        class << self
          # @param origin [String] http(s) origin that internal paths are prefixed with
          def call(node, origin:, user_zone: CommandTower.config.ui.default_zone)
            text_for(node, origin, user_zone)
          end

          private

          def text_for(node, origin, user_zone)
            case node
            when Nodes::Container
              join(node.children.map { |child| text_for(child, origin, user_zone) })
            when Nodes::Button
              target_line(node.label, node.action, origin) || node.label.to_s
            when Nodes::Text, Nodes::Banner
              join([TextDerivation.call(node, user_zone:), *link_lines(node, origin)])
            when Nodes::Component then text_for(node.fallback, origin, user_zone)
            else TextDerivation.call(node, user_zone:)
            end
          end

          def link_lines(node, origin)
            node.spans.filter_map do |span|
              target_line(span.text, span.action, origin) if span.type == "link"
            end
          end

          def target_line(label, action, origin)
            url = action.path ? origin + action.path : action.href
            "#{label}: #{url}" if url.present?
          end

          def join(parts)
            parts.map(&:to_s).reject(&:empty?).join("\n")
          end
        end
      end
    end
  end
end
