# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      class Planner
        def self.call(...)
          new(...).call
        end

        def initialize(
          notification_type_key:,
          recipient_id:,
          preference_state: nil,
          platform_enabled_channels: [],
          message_overrides: nil
        )
          @notification_type_key = notification_type_key.to_s
          @recipient_id = recipient_id
          @preference_state = preference_state
          @platform_enabled_channels = Array(platform_enabled_channels).map(&:to_s)
          @message_overrides = MessageOverrides.normalize(message_overrides)
        end

        def call
          unless @preference_state.nil?
            raise InvalidEvaluationError,
                  "preference_state must not be supplied to Planner; use Preferences::Store"
          end

          declaration = lookup_declaration!
          evaluation = evaluate_preferences!
          readiness = evaluate_readiness!

          selected_channels = declaration.default_channels.select do |channel|
            evaluation.permitted_channels.include?(channel)
          end
          inbox_selected = declaration.inbox_available && evaluation.inbox_permitted

          excluded = build_initial_exclusions(
            declaration:,
            evaluation:,
            selected_channels:,
            inbox_selected:,
          )

          selected_channels, excluded = apply_readiness_intersection(
            selected_channels:,
            excluded:,
            readiness:,
          )

          selected_channels, inbox_selected, excluded =
            apply_overrides(
              declaration:,
              evaluation:,
              readiness:,
              selected_channels:,
              inbox_selected:,
              excluded:,
            )

          if declaration.mandatory && selected_channels.empty? && !inbox_selected
            raise ImpossibleMandatoryPlanError,
                  "mandatory notification type has no selectable destinations: #{@notification_type_key}"
          end

          DestinationPlan.build(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            selected_channels:,
            inbox_selected:,
            excluded_destinations: excluded,
            mandatory: declaration.mandatory,
            preference_evaluation: evaluation,
          )
        end

        private

        def lookup_declaration!
          NotificationTypes.lookup(@notification_type_key)
        rescue NotificationTypes::NotFoundError
          raise UnknownTypeError, "notification type not registered: #{@notification_type_key}"
        end

        def evaluate_preferences!
          result = Preferences.resolve(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            platform_enabled_channels: @platform_enabled_channels,
          )

          unless result.is_a?(Preferences::EvaluationResult)
            raise InvalidEvaluationError, "preference evaluation did not return EvaluationResult"
          end

          result
        rescue Preferences::UnknownTypeError
          raise UnknownTypeError, "notification type not registered: #{@notification_type_key}"
        rescue Preferences::InvalidPreferenceStateError => e
          raise InvalidEvaluationError, e.message
        rescue Preferences::StoreError => e
          raise InvalidEvaluationError, e.message
        end

        def evaluate_readiness!
          RecipientReadiness.for_recipient(
            recipient_id: @recipient_id,
            platform_enabled_channels: @platform_enabled_channels,
          )
        rescue RecipientReadiness::RecipientNotFoundError => e
          raise InvalidEvaluationError, e.message
        end

        def apply_readiness_intersection(selected_channels:, excluded:, readiness:)
          ready_keys = readiness.ready_channel_keys
          selected = selected_channels.dup
          excluded = excluded.dup

          selected_channels.each do |channel|
            next if ready_keys.include?(channel)

            selected.delete(channel)
            exclude_for_unreadiness!(excluded:, channel:, readiness:)
          end

          [selected, excluded]
        end

        def exclude_for_unreadiness!(excluded:, channel:, readiness:)
          channel_result = readiness.channel(channel)
          reason_codes = Array(channel_result&.reason_codes)
          reason =
            reason_codes.first || RecipientReadiness::ReasonCodes::IDENTITY_UNAVAILABLE

          excluded.reject! { |item| item.destination == channel }
          excluded << ExcludedDestination.build(
            destination: channel,
            reason_class: reason,
          )

          OperationLogger.readiness_excluded(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            channel_key: channel,
            reason_codes:,
          )
        end

        def build_initial_exclusions(declaration:, evaluation:, selected_channels:, inbox_selected:)
          excluded = []

          evaluation.suppressed_destinations.each do |suppressed|
            next if suppressed.destination == :inbox && inbox_selected
            next if selected_channels.include?(suppressed.destination)

            excluded << ExcludedDestination.build(
              destination: suppressed.destination,
              reason_class: suppressed.reason_class,
            )
          end

          declaration.allowed_channels.each do |channel|
            next if selected_channels.include?(channel)
            next if excluded.any? { |item| item.destination == channel }

            if evaluation.permitted_channels.include?(channel)
              excluded << ExcludedDestination.build(
                destination: channel,
                reason_class: Preferences::ReasonClasses::SKIPPED_BY_POLICY,
              )
            end
          end

          if declaration.inbox_available && !inbox_selected
            unless excluded.any? { |item| item.destination == :inbox }
              reason =
                evaluation.suppressed_destinations.find { |item| item.destination == :inbox }&.reason_class ||
                Preferences::ReasonClasses::SKIPPED_BY_POLICY

              excluded << ExcludedDestination.build(
                destination: :inbox,
                reason_class: reason,
              )
            end
          end

          excluded
        end

        def apply_overrides(
          declaration:,
          evaluation:,
          readiness:,
          selected_channels:,
          inbox_selected:,
          excluded:
        )
          return [selected_channels, inbox_selected, excluded] if @message_overrides.nil?

          overrides = @message_overrides
          selected = selected_channels.dup
          excluded = excluded.dup
          ready_keys = readiness.ready_channel_keys

          overrides.channels_add.each do |channel|
            unless declaration.allowed_channels.include?(channel)
              raise IllegalOverrideError, "override cannot add channel outside allowed set: #{channel}"
            end

            unless evaluation.permitted_channels.include?(channel)
              raise IllegalOverrideError, "override cannot add channel not permitted by preferences: #{channel}"
            end

            unless ready_keys.include?(channel)
              raise IllegalOverrideError,
                    "override cannot add channel that is not recipient-ready: #{channel}"
            end

            next if selected.include?(channel)

            selected << channel
            excluded.reject! { |item| item.destination == channel }
          end

          overrides.channels_remove.each do |channel|
            selected.delete(channel)
            next if excluded.any? { |item| item.destination == channel }

            excluded << ExcludedDestination.build(
              destination: channel,
              reason_class: Preferences::ReasonClasses::SKIPPED_BY_POLICY,
            )
          end

          unless overrides.inbox.nil?
            if overrides.inbox
              unless declaration.inbox_available && evaluation.inbox_permitted
                raise IllegalOverrideError, "override cannot select inbox when not available/permitted"
              end

              inbox_selected = true
              excluded.reject! { |item| item.destination == :inbox }
            else
              inbox_selected = false
              unless excluded.any? { |item| item.destination == :inbox }
                excluded << ExcludedDestination.build(
                  destination: :inbox,
                  reason_class: Preferences::ReasonClasses::SKIPPED_BY_POLICY,
                )
              end
            end
          end

          [selected, inbox_selected, excluded]
        end
      end
    end
  end
end
