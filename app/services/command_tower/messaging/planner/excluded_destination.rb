# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      ExcludedDestination = Data.define(:destination, :reason_class) do
        ALLOWED_REASON_CLASSES = (
          Preferences::ReasonClasses::ALL + RecipientReadiness::ReasonCodes::ALL
        ).freeze

        def self.build(destination:, reason_class:)
          unless ALLOWED_REASON_CLASSES.include?(reason_class)
            raise ArgumentError, "unknown reason_class: #{reason_class}"
          end

          dest =
            if destination == :inbox || destination == "inbox"
              :inbox
            else
              destination.to_s
            end

          new(destination: dest, reason_class:).freeze
        end
      end
    end
  end
end
