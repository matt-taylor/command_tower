# frozen_string_literal: true

module CommandTower
  module Messaging
    module RecipientReadiness
      ChannelResult = Data.define(
        :channel_key,
        :ready,
        :platform_enabled,
        :platform_configured,
        :recipient_ready,
        :status,
        :reason_codes,
        :endpoint_count,
        :eligible_endpoint_count,
        :eligible_endpoint_ids,
        :resolved_endpoint_id,
        :verification_required,
        :evaluated_at,
      ) do
        def self.build(
          channel_key:,
          ready:,
          platform_enabled:,
          platform_configured:,
          recipient_ready:,
          status:,
          reason_codes:,
          endpoint_count:,
          eligible_endpoint_count:,
          eligible_endpoint_ids:,
          verification_required:,
          resolved_endpoint_id: nil,
          evaluated_at: Time.current
        )
          new(
            channel_key: channel_key.to_s,
            ready: !!ready,
            platform_enabled: !!platform_enabled,
            platform_configured: !!platform_configured,
            recipient_ready: !!recipient_ready,
            status: status.to_s,
            reason_codes: Array(reason_codes).map(&:to_s).freeze,
            endpoint_count: Integer(endpoint_count),
            eligible_endpoint_count: Integer(eligible_endpoint_count),
            eligible_endpoint_ids: Array(eligible_endpoint_ids).map { |id| Integer(id) }.freeze,
            resolved_endpoint_id: resolved_endpoint_id.nil? ? nil : Integer(resolved_endpoint_id),
            verification_required: !!verification_required,
            evaluated_at:,
          ).freeze
        end
      end
    end
  end
end
