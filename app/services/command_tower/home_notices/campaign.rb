# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # A notice the host derives from application state (for example "make your picks"). The platform
    # materializes one row per user per period. Adds the pacing and period macros.
    class Campaign < Notice
      Impressions = Data.define(:max, :cooldown)

      class << self
        # Pacing: at most `max` impressions, at least `cooldown` apart.
        def impressions(max: nil, cooldown: nil)
          return inherited_setting(:@impressions) if max.nil? && cooldown.nil?

          @impressions = Impressions.new(max:, cooldown:)
        end

        # Block returning the period identity for a user, `{ |user:, context:| ... }`. Impressions
        # and acknowledgement reset when the value changes.
        def period_key(&block)
          return inherited_setting(:@period_key) if block.nil?

          @period_key = block
        end
      end
    end
  end
end
