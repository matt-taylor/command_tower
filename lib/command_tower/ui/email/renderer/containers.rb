# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      class Renderer
        # stack, facts, card, divider and component. Stack gaps become child
        # bottom padding; `between` has no email equivalent and renders as stretch.
        module Containers
          ALIGN_ATTR = { "start" => "left", "center" => "center", "end" => "right" }.freeze
          HUGGING = [Nodes::Badge, Nodes::Avatar, Nodes::Button].freeze
          CARD_RADIUS = 12

          private

          def stack(node)
            rows(node.children, Tokens.spacing_px(node.gap), node.align)
          end

          def facts(node)
            rows(node.children, Tokens.spacing_px("md"), nil)
          end

          def card(node)
            padding = Tokens.spacing_px(node.padding)
            inner = rows(node.children, 0, nil)
            case node.surface
            when "raised" then framed(inner, @palette.fetch("card"), @palette.fetch("border"), CARD_RADIUS, padding)
            when "tinted" then tinted(node.tone || "neutral", CARD_RADIUS, padding, inner)
            else framed(inner, nil, nil, 0, padding)
            end
          end

          def divider(_node)
            style = css("background-color" => @palette.fetch("border"), "font-size" => "1px", "line-height" => "1px")
            tag.table(tag.tr(tag.td("", height: 1, style:)), **TABLE, width: "100%")
          end

          def component(node)
            render(node.fallback)
          end

          def rows(children, gap_px, align)
            last = children.size - 1
            trs = children.each_with_index.map do |child, index|
              attr = cell_align(child, align)
              style = css("padding-bottom" => (index == last ? nil : "#{gap_px}px"), "text-align" => attr)
              tag.tr(tag.td(render(child), align: attr, style:))
            end
            tag.table(safe_join(trs), **TABLE, width: "100%")
          end

          def cell_align(child, align)
            ALIGN_ATTR[align] || (HUGGING.any? { |klass| child.is_a?(klass) } ? "left" : nil)
          end

          # A one-cell table with optional background, 1px border and radius.
          def framed(inner, background, border, radius, padding)
            style = css("background-color" => background, "border" => border && "1px solid #{border}",
                        "border-radius" => (radius.positive? ? "#{radius}px" : nil), "padding" => "#{padding}px")
            tag.table(tag.tr(tag.td(inner, style:)), **TABLE, width: "100%")
          end

          def tinted(tone, radius, padding, inner)
            tint = Styles.tint(tone, @palette)
            framed(inner, tint.fetch(:background), tint.fetch(:border), radius, padding)
          end
        end
      end
    end
  end
end
