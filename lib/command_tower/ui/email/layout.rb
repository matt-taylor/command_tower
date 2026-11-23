# frozen_string_literal: true

require "erb"

module CommandTower
  module UI
    module Email
      # Email chrome around a rendered body. Spec: design ux/states.md 5.H.
      # `body_html` and `footer_html` are trusted, already-escaped HTML; `preheader`
      # and `app_name` are plain text and escaped here. Light only, no dark mode.
      module Layout
        CONTAINER_WIDTH = 600
        CONTAINER_RADIUS = 12
        CONTAINER_PADDING = 24
        CANVAS_PADDING_Y = 24
        CANVAS_PADDING_X = 16
        APP_NAME_PADDING_BOTTOM = 12
        FOOTER_PADDING_TOP = 16
        SMALL_TEXT = "font-size:14px;line-height:20px;"
        PREHEADER_STYLE = "display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;" \
                          "opacity:0;overflow:hidden;mso-hide:all;visibility:hidden;"
        HEAD = <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light">
          <meta name="supported-color-schemes" content="light">
          </head>
        HTML

        class << self
          def call(body_html:, palette:, preheader:, footer_html: nil, app_name: nil)
            palette = Styles.validate_palette!(palette)
            [
              HEAD,
              body_open(palette, preheader),
              app_name_row(app_name, palette),
              container_row(body_html, palette),
              footer_row(footer_html, palette),
              "</table>\n</td>\n</tr>\n</table>\n</body>\n</html>\n"
            ].join
          end

          private

          def body_open(palette, preheader)
            background = palette.fetch("background")
            font = Tokens.mapping.fetch("fonts").fetch("sans")
            <<~HTML
              <body style="margin:0;padding:0;background-color:#{background};font-family:#{font};">
              <span aria-hidden="true" style="#{PREHEADER_STYLE}">#{ERB::Util.html_escape(preheader)}</span>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#{background};">
              <tr>
              <td align="center" style="padding:#{CANVAS_PADDING_Y}px #{CANVAS_PADDING_X}px;">
              <table role="presentation" width="#{CONTAINER_WIDTH}" cellpadding="0" cellspacing="0" border="0" style="width:#{CONTAINER_WIDTH}px;max-width:100%;table-layout:fixed;">
            HTML
          end

          def container_row(body_html, palette)
            card_style = "background-color:#{palette.fetch('card')};border:1px solid #{palette.fetch('border')};" \
                         "border-radius:#{CONTAINER_RADIUS}px;padding:#{CONTAINER_PADDING}px;"
            %(<tr>\n<td style="#{card_style}">\n#{body_html}\n</td>\n</tr>\n)
          end

          def app_name_row(app_name, palette)
            return "" if app_name.nil?

            style = "padding-bottom:#{APP_NAME_PADDING_BOTTOM}px;#{SMALL_TEXT}font-weight:600;" \
                    "color:#{palette.fetch('textPrimary')};"
            %(<tr><td style="#{style}">#{ERB::Util.html_escape(app_name)}</td></tr>\n)
          end

          def footer_row(footer_html, palette)
            return "" if footer_html.nil?

            style = "padding-top:#{FOOTER_PADDING_TOP}px;#{SMALL_TEXT}color:#{palette.fetch('textSecondary')};"
            %(<tr><td style="#{style}">#{style_footer_links(footer_html, palette)}</td></tr>\n)
          end

          # Footer links take the footer text colour and are underlined (email.html).
          # A link that already carries its own `style` is left alone.
          def style_footer_links(footer_html, palette)
            link_style = "color:#{palette.fetch('textSecondary')};text-decoration:underline;"
            footer_html.to_str.gsub(/<a(?<attrs>\s[^>]*)?>/i) do |tag|
              attrs = Regexp.last_match[:attrs].to_s
              attrs.match?(/\sstyle\s*=/i) ? tag : %(<a#{attrs} style="#{link_style}">)
            end
          end
        end
      end
    end
  end
end
