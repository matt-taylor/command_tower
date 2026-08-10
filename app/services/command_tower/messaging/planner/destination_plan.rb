# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      DestinationPlan = Data.define(
        :notification_type_key,
        :recipient_id,
        :selected_channels,
        :inbox_selected,
        :excluded_destinations,
        :mandatory,
        :preference_evaluation,
      ) do
        def self.build(
          notification_type_key:,
          recipient_id:,
          selected_channels:,
          inbox_selected:,
          excluded_destinations:,
          mandatory:,
          preference_evaluation:
        )
          unless preference_evaluation.is_a?(Preferences::EvaluationResult)
            raise InvalidEvaluationError, "preference_evaluation must be a Preferences::EvaluationResult"
          end

          new(
            notification_type_key: notification_type_key.to_s,
            recipient_id:,
            selected_channels: Array(selected_channels).map(&:to_s).freeze,
            inbox_selected: !!inbox_selected,
            excluded_destinations: Array(excluded_destinations).freeze,
            mandatory: !!mandatory,
            preference_evaluation:,
          ).freeze
        end
      end
    end
  end
end
