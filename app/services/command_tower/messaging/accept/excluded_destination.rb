# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      ExcludedDestination = Data.define(:destination, :reason_class) do
        def self.build(destination:, reason_class:)
          dest =
            if destination == :inbox || destination.to_s == "inbox"
              :inbox
            else
              destination.to_s
            end

          new(destination: dest, reason_class: reason_class.to_s).freeze
        end

        def sort_key
          destination == :inbox ? "inbox" : destination.to_s
        end
      end
    end
  end
end
