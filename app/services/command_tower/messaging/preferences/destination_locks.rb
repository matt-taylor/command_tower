# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class DestinationLocks
        def self.apply(declaration:, state:)
          locks = declaration.destination_locks
          return state if locks.nil? || locks.empty?

          channels = state.channels.to_h.dup
          inbox = state.inbox

          locks.each do |key, lock|
            enabled = lock.to_s == "forced_on"
            if key.to_s == "inbox"
              inbox = enabled
            else
              channels[key.to_s] = enabled
            end
          end

          PreferenceState.new(
            channels: channels.freeze,
            inbox:,
            urgency: state.urgency,
            sound: state.sound,
          ).freeze
        end
      end
    end
  end
end
