# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      # Domain orchestrator under Produce: validate → idempotency → plan → persist → schedule handoff.
      # Not an ApplicationWorkflow (nested AW under Produce/host workflows is forbidden).
      class Coordinator
        def self.call(**kwargs)
          new(**kwargs).call
        end

        def initialize(
          recipient_id:,
          notification_type_key:,
          host_event_identity:,
          title:,
          body:,
          metadata: nil,
          preference_state: nil,
          platform_enabled_channels:,
          message_overrides: nil
        )
          @recipient_id = recipient_id
          @notification_type_key = notification_type_key
          @host_event_identity = host_event_identity
          @title = title
          @body = body
          @metadata = metadata
          @preference_state = preference_state
          @platform_enabled_channels = platform_enabled_channels
          @message_overrides = message_overrides
        end

        def call
          request = {
            recipient_id: @recipient_id,
            notification_type_key: @notification_type_key,
            host_event_identity: @host_event_identity,
            title: @title,
            body: @body,
            metadata: @metadata,
            preference_state: @preference_state,
            platform_enabled_channels: @platform_enabled_channels,
            message_overrides: @message_overrides,
          }

          OperationLogger.around(request:) do
            validate_request!
            fingerprint = RequestNormalizer.fingerprint(
              title: @title,
              body: @body,
              metadata: @metadata,
              preference_state: @preference_state,
              platform_enabled_channels: @platform_enabled_channels,
              message_overrides: @message_overrides,
            )

            existing = find_by_namespace
            if existing
              return resolve_existing(existing, fingerprint)
            end

            plan = plan!
            persist_new!(request:, plan:, fingerprint:)
          end
        end

        private

        def validate_request!
          errors = []
          errors << "recipient_id is required" if blank?(@recipient_id)
          errors << "notification_type_key is required" if blank?(@notification_type_key)
          errors << "host_event_identity is required" if blank?(@host_event_identity)
          errors << "title is required" if blank?(@title)
          errors << "body is required" if blank?(@body)
          if @platform_enabled_channels.nil?
            errors << "platform_enabled_channels is required"
          end
          unless @preference_state.nil?
            errors << "preference_state must not be supplied; CommandTower loads stored preferences"
          end

          raise ValidationError, errors.join("; ") if errors.any?
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?) ||
            (value.is_a?(String) && value.strip.empty?)
        end

        def find_by_namespace
          Messaging::Communication.find_by_idempotency_namespace(
            user_id: @recipient_id,
            notification_type_key: @notification_type_key,
            host_event_identity: @host_event_identity,
          )
        end

        def resolve_existing(communication, fingerprint)
          if communication.accept_request_fingerprint == fingerprint
            return Result.from_communication(
              reload_aggregate(communication.id),
              idempotent_replay: true,
            )
          end

          raise IdempotencyConflictError,
                "idempotency namespace already accepted with a different request"
        end

        def plan!
          Planner.plan(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            preference_state: nil,
            platform_enabled_channels: @platform_enabled_channels,
            message_overrides: @message_overrides,
          )
        rescue Planner::UnknownTypeError => e
          raise UnknownTypeError, e.message
        rescue Planner::IllegalOverrideError => e
          raise IllegalOverrideError, e.message
        rescue Planner::ImpossibleMandatoryPlanError => e
          raise ImpossibleMandatoryPlanError, e.message
        rescue Planner::InvalidEvaluationError => e
          raise InvalidPreferenceError, e.message
        rescue Preferences::InvalidPreferenceStateError => e
          raise InvalidPreferenceError, e.message
        rescue Preferences::StoreError => e
          raise PersistenceError, e.message
        rescue Preferences::UnknownTypeError => e
          raise UnknownTypeError, e.message
        end

        def persist_new!(request:, plan:, fingerprint:)
          communication = Persister.call(request:, plan:, fingerprint:)
          HandoffScheduler.schedule_after_commit(communication.id)
          Result.from_communication(communication, idempotent_replay: false)
        rescue ActiveRecord::RecordNotUnique => error
          resolve_record_not_unique!(error, fingerprint)
        rescue ActiveRecord::RecordInvalid => e
          raise PersistenceError, e.message
        end

        def resolve_record_not_unique!(error, fingerprint)
          existing = find_by_namespace
          if existing
            return resolve_existing(existing, fingerprint)
          end

          raise PersistenceError, "persistence uniqueness failure"
        end

        def reload_aggregate(id)
          Messaging::Communication.includes(
            :destination_plan,
            :inbox_item,
            :channel_deliveries,
          ).find(id)
        end
      end
    end
  end
end
