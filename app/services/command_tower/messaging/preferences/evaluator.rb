# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Evaluator
        def self.call(...)
          new(...).call
        end

        def initialize(
          notification_type_key:,
          recipient_id:,
          preference_state:,
          platform_enabled_channels:
        )
          @notification_type_key = notification_type_key.to_s
          @recipient_id = recipient_id
          @raw_preference_state = preference_state
          @platform_enabled_channels = Array(platform_enabled_channels).map(&:to_s).freeze
        end

        def call
          declaration = lookup_declaration!
          defaults = PreferenceState.from_declaration_default(declaration.default_preference_state)
          recipient_override = PreferenceState.normalize(@raw_preference_state)

          effective =
            if declaration.user_configurable && recipient_override
              recipient_override.merge_over(defaults)
            else
              defaults
            end

          permitted = []
          suppressed = []

          declaration.allowed_channels.each do |channel|
            if !@platform_enabled_channels.include?(channel)
              suppressed << SuppressedDestination.build(
                destination: channel,
                reason_class: ReasonClasses::SKIPPED_BY_POLICY,
              )
              next
            end

            if declaration.user_configurable && !effective.channel_enabled?(channel, default: true)
              suppressed << SuppressedDestination.build(
                destination: channel,
                reason_class: ReasonClasses::SUPPRESSED_BY_PREFERENCE,
              )
              next
            end

            # Not user-configurable: preference opt-outs ignored; still require default enablement
            if !declaration.user_configurable && !effective.channel_enabled?(channel, default: true)
              suppressed << SuppressedDestination.build(
                destination: channel,
                reason_class: ReasonClasses::SKIPPED_BY_POLICY,
              )
              next
            end

            permitted << channel
          end

          extras = effective.channels.keys - declaration.allowed_channels
          extras.each do |channel|
            suppressed << SuppressedDestination.build(
              destination: channel,
              reason_class: ReasonClasses::SKIPPED_BY_POLICY,
            )
          end

          inbox_permitted, inbox_suppressed = evaluate_inbox(declaration, effective)
          suppressed.concat(inbox_suppressed)

          mandatory_enforced = false
          if declaration.mandatory
            permitted, suppressed, inbox_permitted, mandatory_enforced =
              enforce_mandatory(
                declaration:,
                defaults:,
                permitted:,
                suppressed:,
                inbox_permitted:,
              )
          end

          EvaluationResult.build(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            permitted_channels: permitted.uniq,
            inbox_permitted:,
            suppressed_destinations: suppressed,
            mandatory: declaration.mandatory,
            mandatory_enforced:,
            stored_override_present: false,
            effective_preference_state: effective.to_raw_hash,
          )
        end

        private

        def lookup_declaration!
          NotificationTypes.lookup(@notification_type_key)
        rescue NotificationTypes::NotFoundError
          raise UnknownTypeError, "notification type not registered: #{@notification_type_key}"
        end

        def evaluate_inbox(declaration, effective)
          unless declaration.inbox_available
            return [false, []]
          end

          enabled =
            if effective.inbox.nil?
              true
            else
              effective.inbox
            end

          if declaration.user_configurable && !enabled
            return [
              false,
              [
                SuppressedDestination.build(
                  destination: :inbox,
                  reason_class: ReasonClasses::SUPPRESSED_BY_PREFERENCE,
                ),
              ],
            ]
          end

          if !declaration.user_configurable && !enabled
            return [
              false,
              [
                SuppressedDestination.build(
                  destination: :inbox,
                  reason_class: ReasonClasses::SKIPPED_BY_POLICY,
                ),
              ],
            ]
          end

          [true, []]
        end

        def enforce_mandatory(declaration:, defaults:, permitted:, suppressed:, inbox_permitted:)
          required_channels = declaration.default_channels & declaration.allowed_channels
          required_inbox = declaration.inbox_available && defaults.inbox != false

          enforced = false
          permitted = permitted.dup
          suppressed = suppressed.reject do |item|
            next false unless item.reason_class == ReasonClasses::SUPPRESSED_BY_PREFERENCE

            if item.destination == :inbox
              next false unless required_inbox

              enforced = true
              true
            elsif required_channels.include?(item.destination)
              enforced = true
              true
            else
              false
            end
          end

          required_channels.each do |channel|
            next if permitted.include?(channel)
            next unless @platform_enabled_channels.include?(channel)

            permitted << channel
            enforced = true
            suppressed.reject! do |item|
              item.destination == channel && item.reason_class == ReasonClasses::SUPPRESSED_BY_PREFERENCE
            end
          end

          if required_inbox && !inbox_permitted
            inbox_permitted = true
            enforced = true
            suppressed.reject! { |item| item.destination == :inbox }
          end

          [permitted, suppressed, inbox_permitted, enforced]
        end
      end
    end
  end
end
