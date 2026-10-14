# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Expo
          # Maps a member's neutral urgency to Expo's `interruptionLevel`, degrading to the
          # highest level the host says its shipped binary can honor:
          # critical -> time_sensitive -> normal. Normal is the platform default, so it
          # sends no level. Pure: no I/O.
          class InterruptionLevel
            EXPO_LEVELS = {
              "time_sensitive" => "time-sensitive",
              "critical" => "critical",
            }.freeze
            DEGRADE_ORDER = %w[critical time_sensitive].freeze

            def self.call(urgency:, supported:)
              new(urgency:, supported:).call
            end

            def initialize(urgency:, supported:)
              @urgency = urgency.to_s
              @supported = Array(supported).map(&:to_s)
            end

            # The Expo level string, or nil when the message should carry none.
            def call
              start = DEGRADE_ORDER.index(@urgency)
              return nil if start.nil?

              level = DEGRADE_ORDER.drop(start).find { |candidate| @supported.include?(candidate) }
              EXPO_LEVELS[level]
            end
          end
        end
      end
    end
  end
end
