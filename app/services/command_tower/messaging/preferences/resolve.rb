# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Resolve
        def self.call(...)
          new(...).call
        end

        def initialize(
          notification_type_key:,
          recipient_id:,
          platform_enabled_channels: []
        )
          @notification_type_key = notification_type_key.to_s
          @recipient_id = recipient_id
          @platform_enabled_channels = platform_enabled_channels
        end

        def call
          stored = Store.find(
            recipient_id: @recipient_id,
            notification_type_key: @notification_type_key,
          )
          raw_override = stored&.to_raw_hash

          evaluation = Evaluator.call(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            preference_state: raw_override,
            platform_enabled_channels: @platform_enabled_channels,
          )

          EvaluationResult.build(
            notification_type_key: evaluation.notification_type_key,
            recipient_id: evaluation.recipient_id,
            permitted_channels: evaluation.permitted_channels,
            inbox_permitted: evaluation.inbox_permitted,
            suppressed_destinations: evaluation.suppressed_destinations,
            mandatory: evaluation.mandatory,
            mandatory_enforced: evaluation.mandatory_enforced,
            stored_override_present: !stored.nil?,
            effective_preference_state: evaluation.effective_preference_state,
          )
        end
      end
    end
  end
end
