# frozen_string_literal: true

module CommandTower
  module Messaging
    # Computed-on-demand recipient channel eligibility.
    # No persistence, caching, or background jobs.
    module RecipientReadiness
      module_function

      def for_channel(recipient_id:, channel_key:, platform_enabled_channels: [])
        Evaluate.for_channel(
          recipient_id:,
          channel_key:,
          platform_enabled_channels:,
        )
      end

      def for_recipient(recipient_id:, platform_enabled_channels: [])
        Evaluate.for_recipient(
          recipient_id:,
          platform_enabled_channels:,
        )
      end
    end
  end
end
