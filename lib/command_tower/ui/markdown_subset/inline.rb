# frozen_string_literal: true

module CommandTower
  module UI
    module MarkdownSubset
      # Allowlist walk over inline kramdown elements. Anything not named here
      # is dropped (images, footnotes, math) or reduced to its text (emphasis,
      # code). Links survive only when Hardening accepts the target.
      class Inline
        DROPPED_HTML = %w[script style].freeze
        INLINE_HTML = %w[a b strong em i u span code small sub sup br abbr mark cite q s del ins].freeze
        INLINE_TYPES = %i[text strong em a codespan br smart_quote typographic_sym entity footnote math
                          abbreviation img].freeze
        SMART_QUOTES = { lsquo: "‘", rsquo: "’", ldquo: "“", rdquo: "”" }.freeze
        TYPOGRAPHIC = { mdash: "—", ndash: "–", hellip: "…", laquo: "«", raquo: "»", laquo_space: "« ",
                        raquo_space: " »" }.freeze

        class << self
          def segments(elements, strong: false, href: nil)
            elements.flat_map { |element| for_element(element, strong:, href:) }
          end

          def plain_text(element)
            return "" if element.type == :img
            return element.value.to_s if %i[text codespan].include?(element.type)

            segments(element.children).map(&:text).join
          end

          # True when the element belongs inside a paragraph rather than being a block.
          def inline?(element)
            return INLINE_TYPES.include?(element.type) unless element.type == :html_element

            DROPPED_HTML.include?(element.value) || INLINE_HTML.include?(element.value)
          end

          private

          def for_element(element, strong:, href:)
            case element.type
            when :text then [Segment.new(element.value.to_s.gsub(/\s*\n\s*/, " "), strong, href)]
            when :strong then segments(element.children, strong: true, href:)
            when :a then link(element, strong:)
            when :html_element then html(element, strong:, href:)
            when :em, :abbreviation then segments(element.children, strong:, href:)
            else literal(element, strong:, href:)
            end
          end

          def literal(element, strong:, href:)
            text = literal_text(element)
            text ? [Segment.new(text, strong, href)] : []
          end

          def literal_text(element)
            case element.type
            when :br then "\n"
            when :codespan then element.value.to_s
            when :entity then element.value.char
            when :smart_quote then SMART_QUOTES[element.value]
            when :typographic_sym then TYPOGRAPHIC[element.value]
            end
          end

          def html(element, strong:, href:)
            return [] if DROPPED_HTML.include?(element.value)

            segments(element.children, strong: strong || %w[b strong].include?(element.value), href:)
          end

          def link(element, strong:)
            target = element.attr["href"].to_s
            label = segments(element.children, strong:)
            return label unless safe_link?(target)

            label.map { |segment| segment.href ? segment : Segment.new(segment.text, false, target) }
          end

          def safe_link?(target)
            Hardening.internal_path?(target) || Hardening.external_href_code(target).nil?
          end
        end
      end
    end
  end
end
