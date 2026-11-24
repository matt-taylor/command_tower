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
          message_overrides: nil,
          conversation_key: nil,
          conversation_title: nil
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
          @conversation_key = conversation_key
          @conversation_title = conversation_title
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
            conversation_key: @conversation_key,
            conversation_title: @conversation_title,
          }

          OperationLogger.around(request:) do
            definition = definition_class
            validate_request!(defined_type: !definition.nil?)
            fingerprint = RequestNormalizer.fingerprint(
              title: @title,
              body: @body,
              metadata: @metadata,
              preference_state: @preference_state,
              platform_enabled_channels: @platform_enabled_channels,
              message_overrides: @message_overrides,
              metadata_version: definition&.metadata_version,
            )

            existing = find_by_namespace
            if existing
              return resolve_existing(existing, fingerprint)
            end

            request = with_definition_fields(request, definition) if definition
            plan = plan!
            persist_new!(request:, plan:, fingerprint:)
          end
        end

        private

        # The MessageDefinition class for a registered, definition-backed type; nil for undefined
        # and unregistered types (the planner reports the latter).
        def definition_class
          return nil unless NotificationTypes.registered?(@notification_type_key)

          message = NotificationTypes.lookup(@notification_type_key).message
          klass = message&.safe_constantize
          klass if klass.is_a?(Class) && klass < MessageDefinition
        end

        # Stored title/body/slots/zone/version come from the definition. Metadata violations fail
        # the request in strict mode and are logged and degraded otherwise.
        def with_definition_fields(request, definition)
          resolution = ResolveCommunicationSlots.call(
            notification_type_key: @notification_type_key,
            definition:,
            metadata: @metadata,
            recipient_id: @recipient_id,
          )
          handle_resolution_failure!(resolution) if resolution.failure?

          request.merge(
            title: resolution.title,
            body: resolution.body,
            slots: resolution.slots,
            render_zone: resolution.render_zone,
            metadata_version: resolution.metadata_version,
          )
        end

        def handle_resolution_failure!(resolution)
          unless resolution.degradable? && !CommandTower.config.messaging.strict_definitions
            raise ValidationError, resolution.failure_message
          end

          Contract::Observability::Publisher.warn(
            event: "messaging.accept.metadata_schema_violation",
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            attributes: resolution.schema_errors,
          )
        end

        def validate_request!(defined_type: false)
          errors = []
          errors << "recipient_id is required" if blank?(@recipient_id)
          errors << "notification_type_key is required" if blank?(@notification_type_key)
          errors << "host_event_identity is required" if blank?(@host_event_identity)
          if defined_type
            # Defined types derive title and body from the definition; explicit copy is rejected in
            # every environment (D17). Producers decide whether to fail or drop it before accepting.
            errors << "title must not be supplied for a defined type" unless blank?(@title)
            errors << "body must not be supplied for a defined type" unless blank?(@body)
          else
            errors << "title is required" if blank?(@title)
            errors << "body is required" if blank?(@body)
          end
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
          if conversation_pair_invalid?(e)
            raise ValidationError, e.record.errors.full_messages.join("; ")
          end

          raise PersistenceError, e.message
        end

        def conversation_pair_invalid?(error)
          names = error.record.errors.attribute_names.map(&:to_sym)
          names.any? && (names - %i[conversation_key conversation_title]).empty?
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
