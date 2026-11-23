# frozen_string_literal: true

module CommandTower
  module UI
    # Normalizes a bare host for exact-match allowlists: NFC, lowercase,
    # non-ASCII labels converted to punycode (RFC 3492). Returns nil when the
    # input is not a bare host (scheme, port, path, userinfo, wildcard, spaces).
    module Hostname
      LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
      FORBIDDEN = %r{[\s/\\:@*?#%\u0000-\u001f]}
      MAX_LENGTH = 253

      def self.normalize(value)
        return nil unless value.is_a?(String)

        host = value.strip.unicode_normalize(:nfc).downcase.chomp(".")
        return nil unless bare_host?(host)

        labels = host.split(".", -1).map { |label| ascii_label(label) }
        labels.any?(&:nil?) ? nil : labels.join(".")
      rescue ArgumentError, Encoding::UndefinedConversionError
        nil
      end

      def self.bare_host?(host)
        !host.empty? && host.length <= MAX_LENGTH && !host.match?(FORBIDDEN)
      end
      private_class_method :bare_host?

      def self.ascii_label(label)
        ascii = label.ascii_only? ? label : "xn--#{Punycode.encode(label)}"
        ascii.match?(LABEL) ? ascii : nil
      end
      private_class_method :ascii_label

      # RFC 3492 encoder for one label.
      class Punycode
        BASE = 36
        T_MIN = 1
        T_MAX = 26
        SKEW = 38
        DAMP = 700
        INITIAL_BIAS = 72
        INITIAL_N = 128

        def self.encode(input)
          new(input).encode
        end

        def initialize(input)
          @codepoints = input.codepoints
          @output = @codepoints.select { |cp| cp < INITIAL_N }.map(&:chr)
          @basic = @handled = @output.length
          @next_cp = INITIAL_N
          @delta = 0
          @bias = INITIAL_BIAS
        end

        def encode
          @output << "-" if @basic.positive?
          encode_next_codepoint while @handled < @codepoints.length
          @output.join
        end

        private

        def encode_next_codepoint
          smallest = @codepoints.select { |cp| cp >= @next_cp }.min
          @delta += (smallest - @next_cp) * (@handled + 1)
          @next_cp = smallest
          @codepoints.each { |cp| handle(cp) }
          @delta += 1
          @next_cp += 1
        end

        def handle(codepoint)
          @delta += 1 if codepoint < @next_cp
          return unless codepoint == @next_cp

          emit_delta
          @bias = adapt(@handled + 1, @handled == @basic)
          @delta = 0
          @handled += 1
        end

        def emit_delta
          quotient = @delta
          step = BASE
          loop do
            limit = threshold(step)
            break if quotient < limit

            @output << digit(limit + ((quotient - limit) % (BASE - limit)))
            quotient = (quotient - limit) / (BASE - limit)
            step += BASE
          end
          @output << digit(quotient)
        end

        def threshold(step)
          return T_MIN if step <= @bias
          return T_MAX if step >= @bias + T_MAX

          step - @bias
        end

        def digit(value)
          (value < 26 ? value + 97 : value + 22).chr
        end

        def adapt(num_points, first_time)
          delta = first_time ? @delta / DAMP : @delta / 2
          delta += delta / num_points
          step = 0
          while delta > ((BASE - T_MIN) * T_MAX) / 2
            delta /= BASE - T_MIN
            step += BASE
          end
          step + (((BASE - T_MIN + 1) * delta) / (delta + SKEW))
        end
      end
    end
  end
end
