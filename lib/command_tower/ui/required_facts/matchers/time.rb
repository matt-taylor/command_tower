# frozen_string_literal: true

module CommandTower
  module UI
    module RequiredFacts
      module Matchers
        # Passes when the text contains the `:time`-preset rendering of the metadata
        # instant (for example "6:00 AM PT") in the fact's zone. Every time-of-day
        # preset contains that string. `zone` is a metadata key holding an IANA
        # zone, `:user` (the render zone), or nil (also the render zone).
        # Host matcher protocol: `call(text:, metadata:, t:) -> Boolean`.
        class Time
          def initialize(key:, zone:, render_zone:)
            @key = key.to_s
            @zone = zone
            @render_zone = render_zone
          end

          def call(text:, metadata:, t:) # rubocop:disable Naming/MethodParameterName
            value = Verdict.fetch(metadata, @key)
            return false if value.nil?

            text.to_s.include?(t.call(value, zone: zone_for(metadata), format: :time))
          end

          private

          def zone_for(metadata)
            return @render_zone if @zone.nil? || @zone.to_s == TimeFormatter::USER_ZONE

            Verdict.fetch(metadata, @zone.to_s) || @render_zone
          end
        end
      end
    end
  end
end
