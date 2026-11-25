# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # A notice a host workflow pushes to one user (for example "class canceled") through
    # `Deliver`. Adds the composer macro.
    class Delivery < Notice
      COMPOSERS = %i[message].freeze

      class << self
        def composer(value = nil)
          return inherited_setting(:@composer) if value.nil?

          unless COMPOSERS.include?(value)
            raise ArgumentError, "composer must be one of #{COMPOSERS.inspect} (got #{value.inspect})"
          end

          @composer = value
        end
      end
    end
  end
end
