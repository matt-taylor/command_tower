# frozen_string_literal: true

module CommandTower
  module UI
    module MarkdownSubset
      # Splits styled text into runs that fit one `text` node: under the string
      # limit and the span cap, cut at word boundaries (an unbroken string is
      # cut at the limit). Returns arrays of Segments; no run is blank.
      class Chunker
        LIMIT = Limits::MAX_STRING_LENGTH - 1

        def self.call(segments)
          new.call(segments)
        end

        def call(segments)
          @runs = []
          reset
          tokens(segments).each { |token| add(token) }
          flush
          @runs
        end

        private

        def reset
          @current = []
          @length = 0
        end

        def add(token)
          # No doubled whitespace (a dropped image or a break leaves some behind).
          token.text = token.text.lstrip if open_whitespace?
          return if token.text.empty?
          return add_whitespace(token) if token.text.strip.empty?

          flush if @length + token.text.length > LIMIT
          append(token)
        end

        def open_whitespace?
          @current.last&.text&.match?(/\s\z/)
        end

        # Span text may not be blank, so whitespace-only tokens join the previous span.
        def add_whitespace(token)
          return if @current.empty?

          @current.last.text += token.text
          @length += token.text.length
        end

        def append(token)
          last = @current.last
          if last && same_style?(last, token)
            last.text += token.text
          else
            flush if @current.length >= Limits::MAX_SPANS
            @current << token
          end
          @length += token.text.length
        end

        def flush
          run = trim(@current)
          @runs << run unless run.empty?
          reset
        end

        def tokens(segments)
          segments.flat_map do |segment|
            segment.text.scan(/\s*\S+\s*|\s+/).flat_map do |word|
              word.scan(/.{1,#{LIMIT}}/m).map { |piece| Segment.new(piece, segment.strong, segment.href) }
            end
          end
        end

        def same_style?(first, second)
          first.strong == second.strong && first.href == second.href
        end

        def trim(run)
          run = run.map(&:dup)
          run.first&.text = run.first.text.lstrip
          run.last&.text = run.last.text.rstrip
          run.reject { |segment| segment.text.strip.empty? }
        end
      end
    end
  end
end
