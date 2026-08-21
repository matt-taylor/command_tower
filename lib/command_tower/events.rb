# frozen_string_literal: true

module CommandTower
  module Events
    PREFIX = "command_tower"
    SEGMENT = /\A[a-z][a-z0-9_]*\z/
    SNAPSHOT_KEYS = %i[
      execution_uuid
      correlation_id
      request_id
      causation_id
      source
      user_id
      originating_administrator_id
      effective_user_id
      impersonation_active
    ].freeze
    SCALAR_TYPES = [NilClass, TrueClass, FalseClass, Integer, Float, String, Symbol].freeze

    WORKFLOW_STARTED = "command_tower.lifecycle.workflow.started"
    WORKFLOW_COMPLETED = "command_tower.lifecycle.workflow.completed"
    SERVICE_STARTED = "command_tower.lifecycle.service.started"
    SERVICE_COMPLETED = "command_tower.lifecycle.service.completed"

    module_function

    def instrument_name(category:, name:)
      category_segment = normalize_segment(category, field: "category")
      name_segments = name.to_s.split(".")
      raise ArgumentError, "name must contain at least one segment" if name_segments.empty?

      normalized_name = name_segments.map { |segment| normalize_segment(segment, field: "name") }
      "#{PREFIX}.#{category_segment}.#{normalized_name.join(".")}"
    end

    def snapshot
      SNAPSHOT_KEYS.each_with_object({}) do |key, memo|
        memo[key] = CommandTower::Current.public_send(key)
      end.freeze
    end

    def publish(category:, name:, payload: {}, subject: nil, layer: nil)
      event_payload = snapshot.merge(event_uuid: SecureRandom.uuid)
      event_payload[:subject] = subject if subject
      event_payload[:layer] = layer if layer
      event_payload.merge!(sanitize_payload(payload))
      ActiveSupport::Notifications.instrument(instrument_name(category:, name:), event_payload.freeze)
    end

    def publish_audit(name:, envelope:)
      raise CommandTower::Audit::InvalidPayloadError, "audit envelope must be a Hash" unless envelope.is_a?(Hash)

      CommandTower::Audit::Payload.validate!(envelope[:changes] || {}, path: "changes")
      CommandTower::Audit::Payload.validate!(envelope[:metadata] || {}, path: "metadata")
      CommandTower::Audit::Payload.enforce_size!(envelope)

      event_payload = snapshot.merge(
        event_uuid: SecureRandom.uuid,
        action: name.to_s,
        occurred_at: envelope[:occurred_at] || Time.now.utc.iso8601(6)
      )
      %i[
        actor_user_id
        affected_user_id
        effective_user_id
        originating_administrator_id
        impersonation_active
        attribution_mode
        subject_type
        subject_id
        subject_label
        user_id
        scope_class
        host_context_type
        host_context_identifier
        changes
        metadata
      ].each do |key|
        event_payload[key] = envelope[key] if envelope.key?(key)
      end

      ActiveSupport::Notifications.instrument(instrument_name(category: :audit, name:), event_payload.freeze)
    end

    def publish_lifecycle(layer:, phase:, subject:, outcome: nil, duration_ms: nil, error_class: nil, error_codes: nil, log_level: nil, log_lifecycle: false)
      extra = {}
      extra[:outcome] = outcome if phase == :completed
      extra[:duration_ms] = duration_ms if phase == :completed && !duration_ms.nil?
      extra[:error_class] = error_class if error_class
      extra[:error_codes] = error_codes if error_codes
      extra[:log_level] = log_level if log_level
      extra[:log_lifecycle] = log_lifecycle ? true : false
      publish(
        category: :lifecycle,
        name: "#{layer}.#{phase}",
        payload: extra,
        subject:,
        layer:
      )
    end

    def around_execution(layer:, subject:, log_lifecycle: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      publish_lifecycle(layer:, phase: :started, subject:, log_lifecycle:)
      record = { result: nil, unexpected: nil, error_codes: nil, log_level: nil }
      begin
        yield record
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)
        publish_lifecycle(
          layer:,
          phase: :completed,
          subject:,
          outcome: outcome_for(layer:, record:),
          duration_ms:,
          error_class: record[:unexpected]&.class&.name,
          error_codes: error_codes_for(record),
          log_level: log_level_for(record),
          log_lifecycle:
        )
      end
      record[:result]
    end

    def outcome_for(layer:, record:)
      return :error if record[:unexpected]

      result = record[:result]
      return result if layer == :service && %i[success failure].include?(result)
      return :success if result.respond_to?(:success?) && result.success?
      return :deferred if result.respond_to?(:deferred?) && result.deferred?
      return :failure if result.respond_to?(:failure?) && result.failure?

      :error
    end

    def error_codes_for(record)
      return record[:error_codes] if record[:error_codes]
      return nil unless record[:result].respond_to?(:errors)

      codes = Array(record[:result].errors).filter_map { |error| error.code if error.respond_to?(:code) }
      codes.empty? ? nil : codes
    end

    def log_level_for(record)
      return :error if record[:unexpected]
      return record[:log_level] if record[:log_level]
      return nil unless record[:result].respond_to?(:errors)

      Array(record[:result].errors).filter_map { |error| error.log_level if error.respond_to?(:log_level) }.first
    end

    def sanitize_payload(payload)
      raise ArgumentError, "payload must be a Hash" unless payload.nil? || payload.is_a?(Hash)

      (payload || {}).each_with_object({}) do |(key, value), memo|
        next unless scalar_key?(key)
        next unless scalar_value?(value)

        memo[key.to_sym] = value
      end
    end

    def normalize_segment(value, field:)
      segment = value.to_s
      unless segment.match?(SEGMENT)
        raise ArgumentError, "invalid #{field} segment #{value.inspect}"
      end

      segment
    end

    def scalar_key?(key)
      key.is_a?(String) || key.is_a?(Symbol)
    end

    def scalar_value?(value)
      return true if SCALAR_TYPES.any? { |type| value.is_a?(type) }
      return false unless value.is_a?(Array)

      value.all? { |item| SCALAR_TYPES.any? { |type| item.is_a?(type) } }
    end
  end
end
