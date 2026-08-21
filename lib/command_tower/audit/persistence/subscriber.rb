# frozen_string_literal: true

module CommandTower
  module Audit
    module Persistence
      class Subscriber
        PATTERN = /\Acommand_tower\.audit(?:\.|\z)/

        class << self
          def attach!
            detach!
            subscriber = new
            @subscriptions = [
              ActiveSupport::Notifications.subscribe(PATTERN) do |name, started, finished, id, payload|
                event = ActiveSupport::Notifications::Event.new(name, started, finished, id, payload)
                subscriber.call(event)
              end
            ]
          end

          def detach!
            Array(@subscriptions).each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
            @subscriptions = []
          end

          def subscriptions
            Array(@subscriptions)
          end
        end

        def call(event)
          payload = event.payload.to_h.with_indifferent_access
          return unless persistable?(payload)

          persist!(payload)
        end

        private

        def persistable?(payload)
          payload[:action].present? && payload[:event_uuid].present?
        end

        def persist!(payload)
          action = payload.fetch(:action).to_s
          definition = CommandTower.config.registry.audit.fetch(action)

          CommandTower::Audit::Event.create!(
            event_uuid: payload.fetch(:event_uuid),
            action: action,
            occurred_at: parse_occurred_at(payload.fetch(:occurred_at)),
            scope_class: payload.fetch(:scope_class).to_s,
            host_context_type: payload[:host_context_type],
            host_context_identifier: payload[:host_context_identifier],
            execution_uuid: payload[:execution_uuid],
            correlation_id: payload[:correlation_id],
            request_id: payload[:request_id],
            causation_id: payload[:causation_id],
            source: payload[:source]&.to_s,
            actor_user_id: payload[:actor_user_id],
            affected_user_id: payload[:affected_user_id],
            effective_user_id: payload[:effective_user_id],
            originating_administrator_id: payload[:originating_administrator_id],
            impersonation_active: payload[:impersonation_active] == true,
            attribution_mode: payload.fetch(:attribution_mode).to_s,
            subject_type: payload[:subject_type],
            subject_id: payload[:subject_id],
            subject_label: payload[:subject_label],
            change_set: payload[:changes] || {},
            metadata: payload[:metadata] || {},
            user_history: definition.user_history,
            sensitive_fields: Array(definition.sensitive_fields).map(&:to_s),
            retention: definition.retention.to_s
          )
        end

        def parse_occurred_at(value)
          return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

          Time.iso8601(value.to_s)
        end
      end
    end
  end
end
