# frozen_string_literal: true

module CommandTower
  module ClientCompatibility
    # Strict client-version identity parsing (authority §12).
    #
    # `Gem::Version` alone is too permissive: it accepts partial shapes such as
    # "1" or "1.2". The authority requires the full MAJOR.MINOR.PATCH shape,
    # with an optional dot-delimited prerelease tail (e.g. "1.2.3.beta.1").
    # Build metadata (e.g. "+build"), hyphenated prerelease tokens, and any
    # other malformed shape are rejected as invalid identity — never coerced
    # into a "valid but low" version.
    module Version
      FORMAT = /\A[vV]?\d+\.\d+\.\d+(\.[A-Za-z0-9]+)*\z/

      module_function

      # Returns a normalized (leading "v"/"V" stripped) version string, or nil
      # when the raw value does not conform to the strict MAJOR.MINOR.PATCH
      # (+ optional prerelease) shape.
      def normalize(raw)
        token = raw.to_s.strip
        return nil if token.empty?
        return nil unless token.match?(FORMAT)

        token.sub(/\A[vV]/, "")
      end

      def valid?(raw)
        !normalize(raw).nil?
      end

      # Returns a Gem::Version for a strictly-valid raw value, or nil otherwise.
      # Callers that need a hard failure on invalid input should check
      # `valid?`/`normalize` explicitly rather than relying on Gem::Version's
      # own (looser) parsing.
      def parse(raw)
        normalized = normalize(raw)
        return nil if normalized.nil?

        Gem::Version.new(normalized)
      end
    end
  end
end
