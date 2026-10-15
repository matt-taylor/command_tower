# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Corrections
        CorrectionEntry = Data.define(
          :channel_key,
          :submitted,
          :effective,
          :reason_code,
          :reason,
        )

        def self.build(submitted:, destinations:)
          return [].freeze if submitted.nil? || submitted.empty?

          submitted.filter_map do |channel_key, submitted_value|
            destination = destinations[channel_key.to_s]
            next if destination.nil?

            entry = normalize_destination(destination)

            next if submitted_value == entry.effective

            CorrectionEntry.new(
              channel_key: channel_key.to_s,
              submitted: !!submitted_value,
              effective: entry.effective,
              reason_code: entry.reason_code,
              reason: entry.reason,
            )
          end.freeze
        end

        def self.normalize_destination(destination)
          return destination if destination.is_a?(Destinations::DestinationEntry)

          Destinations::DestinationEntry.new(
            state: destination.fetch(:state) { destination["state"] },
            effective: destination.fetch(:effective) { destination["effective"] },
            reason_code: destination.fetch(:reason_code) { destination["reasonCode"] },
            reason: destination.fetch(:reason) { destination["reason"] },
          )
        end
        private_class_method :normalize_destination
      end
    end
  end
end
