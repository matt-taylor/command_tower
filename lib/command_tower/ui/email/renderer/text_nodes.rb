# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      class Renderer
        # text, time, banner, key_value and stat_tile. Icons are dropped.
        module TextNodes
          LABEL_WIDTH = 96
          ROW_GAP = 8

          private

          def text(node)
            tag.div(spans(node.spans), style: type_style(node.variant, node.text_tone))
          end

          def instant(node)
            tag.div(time_text(node), style: type_style(node.variant, node.text_tone))
          end

          def banner(node)
            body = tag.div(spans(node.spans), style: type_style("body", "primary"))
            bold = type_style("body", "primary", "font-weight" => 600)
            title = tag.div(node.title, style: bold) if node.title.present?
            tinted(node.tone, 6, 12, safe_join([title, body].compact))
          end

          def key_value(node)
            labelled = node.items.any? { |item| item.label.present? }
            rows = node.items.map { |item| key_value_row(item, labelled) }
            tag.table(safe_join(rows, spacer_row(labelled ? 2 : 1)), **TABLE, width: "100%")
          end

          def key_value_row(item, labelled)
            label = tag.td(item.label.to_s, valign: "top", width: LABEL_WIDTH, style: label_style) if labelled
            tag.tr(safe_join([label, tag.td(item_value(item), valign: "top", style: value_style)].compact))
          end

          def stat_tile(node)
            label = tag.div(node.label, style: type_style("caption", "secondary"))
            big = type_style("heading_m", "primary", "font-size" => "24px", "line-height" => "32px")
            value = tag.div(node.value, style: big)
            tinted(node.tone || "neutral", 6, 12, safe_join([label, value]))
          end

          def spans(list)
            safe_join(list.map { |span| span_html(span) })
          end

          def span_html(span)
            if span.type == "link"
              weight = span.strong ? 600 : 500
              tag.a(span.text, href: link_href(span.action), style: css(link_pairs.merge("font-weight" => weight)))
            elsif span.strong
              tag.span(span.text, style: css("font-weight" => 600))
            else
              span.text
            end
          end

          def item_value(item)
            item.value.is_a?(Nodes::Instant) ? time_text(item.value) : item.value.to_s
          end

          def time_text(node)
            TimeFormatter.call(at: node.at, zone: node.zone, format: node.format, label: node.label)
          end

          def spacer_row(columns)
            style = css("font-size" => "#{ROW_GAP}px", "line-height" => "#{ROW_GAP}px")
            tag.tr(tag.td("", colspan: columns, height: ROW_GAP, style:))
          end
        end
      end
    end
  end
end
