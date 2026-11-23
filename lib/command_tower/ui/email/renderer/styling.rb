# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      class Renderer
        # Inline-style building blocks shared by the node renderers. Colours come
        # only from the validated palette; sizes only from the token mapping.
        module Styling
          private

          def css(pairs)
            pairs.filter_map { |name, value| "#{name}:#{value};" unless value.nil? }.join
          end

          def sans
            Tokens.mapping.fetch("fonts").fetch("sans")
          end

          def type_style(variant, tone, extra = {})
            css(type_pairs(variant, tone).merge(extra))
          end

          def type_pairs(variant, tone)
            step = Tokens.type_step(variant)
            font = step.fetch("mono") ? Tokens.mapping.fetch("fonts").fetch("mono") : sans
            {
              "margin" => 0, "font-family" => font,
              "font-size" => "#{step.fetch('size')}px", "line-height" => "#{step.fetch('lineHeight')}px",
              "font-weight" => step.fetch("weight"), "letter-spacing" => step["tracking"],
              "text-transform" => step.fetch("uppercase") ? "uppercase" : nil,
              "color" => @palette.fetch(Tokens.mapping.fetch("textTones").fetch(tone))
            }
          end

          def link_pairs
            { "color" => @palette.fetch("primary"), "text-decoration" => "underline" }
          end

          def small_link_style
            css(link_pairs.merge("font-size" => "14px", "line-height" => "20px", "font-weight" => 500))
          end

          def label_style
            css(type_pairs("caption", "secondary").merge("line-height" => "24px", "padding-right" => "8px"))
          end

          def value_style
            css(type_pairs("body", "primary").merge("word-break" => "break-word"))
          end

          def badge_style(tone)
            background, color = badge_colors(tone)
            css("background-color" => background, "color" => color, "font-size" => "12px", "line-height" => "16px",
                "font-weight" => 600, "padding" => "2px 10px", "border-radius" => "9999px", "font-family" => sans)
          end

          def badge_colors(tone)
            case tone
            when "neutral" then [@palette.fetch("muted"), @palette.fetch("foreground")]
            when "warning" then [@palette.fetch("warning"), @palette.fetch("foreground")]
            else [@palette.fetch(Tokens.tone_palette_key(tone)), @palette.fetch("primaryForeground")]
            end
          end

          def button_cell_style(variant)
            if variant == "primary"
              css("background-color" => @palette.fetch("primary"), "border-radius" => "6px")
            else
              css("background-color" => @palette.fetch("background"),
                  "border" => "1px solid #{@palette.fetch('border')}", "border-radius" => "6px")
            end
          end

          def button_link_style(variant)
            primary = variant == "primary"
            css("display" => "block", "padding" => primary ? "10px 16px" : "9px 15px", "text-decoration" => "none",
                "font-family" => sans, "font-size" => "14px", "line-height" => "20px", "font-weight" => 500,
                "color" => @palette.fetch(primary ? "primaryForeground" : "foreground"))
          end

          def avatar_style(size)
            css("width" => "#{size}px", "height" => "#{size}px", "background-color" => @palette.fetch("muted"),
                "color" => @palette.fetch("foreground"), "font-family" => sans, "font-size" => "14px",
                "font-weight" => 500, "border-radius" => "50%", "text-align" => "center")
          end
        end
      end
    end
  end
end
