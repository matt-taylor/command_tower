# frozen_string_literal: true

module CommandTower
  module UI
    module Catalog
      # Parses the X-UI-Catalog request header. Missing, blank, non-integer or
      # non-positive gives 1; a higher number is clamped to CATALOG.
      def self.from_header(value)
        return 1 unless /\A\s*\d+\s*\z/.match?(value.to_s)

        parsed = value.to_s.strip.to_i
        return 1 if parsed <= 0

        [parsed, CommandTower::UI::CATALOG].min
      end
    end
  end
end
