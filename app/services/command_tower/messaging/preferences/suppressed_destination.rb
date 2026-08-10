# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      SuppressedDestination = Data.define(:destination, :reason_class) do
        def self.build(destination:, reason_class:)
          unless ReasonClasses::ALL.include?(reason_class)
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
