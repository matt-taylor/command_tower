# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Raised when one channel's composer or renderer fails while building a gallery preview.
        # Carries the channel and the error class only; the original message can hold metadata
        # values, so it is dropped.
        class ChannelFailed < StandardError
          # Runs the block, turning any StandardError into a ChannelFailed for `channel`.
          def self.guard(channel)
            yield
          rescue ChannelFailed
            raise
          rescue StandardError => e
            raise new(channel, e.class.name)
          end

          attr_reader :channel, :error_class

          def initialize(channel, error_class)
            @channel = channel
            @error_class = error_class
            super("channel #{channel} failed")
          end
        end
      end
    end
  end
end
