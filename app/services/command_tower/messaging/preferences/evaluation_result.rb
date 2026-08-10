# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      EvaluationResult = Data.define(
        :notification_type_key,
        :recipient_id,
        :permitted_channels,
        :inbox_permitted,
        :suppressed_destinations,
        :mandatory,
        :mandatory_enforced,
        :stored_override_present,
        :effective_preference_state,
      ) do
        def self.build(
          notification_type_key:,
          recipient_id:,
          permitted_channels:,
          inbox_permitted:,
          suppressed_destinations:,
          mandatory:,
          mandatory_enforced:,
          stored_override_present: false,
          effective_preference_state: nil
        )
          new(
            notification_type_key: notification_type_key.to_s,
            recipient_id:,
            permitted_channels: Array(permitted_channels).map(&:to_s).freeze,
            inbox_permitted: !!inbox_permitted,
            suppressed_destinations: Array(suppressed_destinations).freeze,
            mandatory: !!mandatory,
            mandatory_enforced: !!mandatory_enforced,
            stored_override_present: !!stored_override_present,
            effective_preference_state: freeze_effective_state(effective_preference_state),
          ).freeze
        end

        def self.freeze_effective_state(state)
          return nil if state.nil?

          hash = state.to_h.transform_keys(&:to_s)
          channels = hash["channels"]
          frozen_channels =
            if channels.nil?
              {}.freeze
            else
              channels.to_h.transform_keys(&:to_s).transform_values { |value| !!value }.freeze
            end

          result = { "channels" => frozen_channels }
          result["inbox"] = !!hash["inbox"] if hash.key?("inbox")
          result.freeze
        end
        private_class_method :freeze_effective_state
      end
    end
  end
end
