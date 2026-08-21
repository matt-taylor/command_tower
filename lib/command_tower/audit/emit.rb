# frozen_string_literal: true

require "command_tower/audit/attribution"
require "command_tower/audit/payload"

module CommandTower
  module Audit
    module Emit
      module_function

      def call(name:, subject: nil, affected_user: nil, changes: {}, metadata: {}, attribution_mode: nil, subject_label: nil, scope_class: :global, host_context: nil)
        registry_name = normalized_event_name(name)
        definition = CommandTower.config.registry.audit.fetch(registry_name)
        return nil unless definition.enabled?

        assert_subject!(definition, subject)
        affected_user_id = extract_user_id(affected_user, required: definition.affected_user_required)
        validated_changes = Payload.validate_changes!(changes || {}, allowed_keys: definition.allowed_changes)
        validated_metadata = Payload.validate_metadata!(metadata)
        attribution = Attribution.resolve(affected_user_id:, attribution_mode:)
        snapshot = subject_snapshot(subject, subject_label)
        normalized_scope_class = normalize_scope_class!(scope_class)
        host_context_fields = normalize_host_context!(host_context, scope_class: normalized_scope_class)

        CommandTower::Events.publish_audit(
          name: registry_name,
          envelope: attribution.merge(snapshot).merge(host_context_fields).merge(
            action: registry_name,
            occurred_at: Time.now.utc.iso8601(6),
            scope_class: normalized_scope_class,
            changes: validated_changes,
            metadata: validated_metadata
          )
        )
      end

      def normalized_event_name(name)
        CommandTower.config.registry.audit.fetch(name)
        name.to_s.split(".").map { |segment| CommandTower::Events.normalize_segment(segment, field: "name") }.join(".")
      end

      def assert_subject!(definition, subject)
        return unless definition.subject_required
        return unless subject.nil?

        raise MissingSubjectError, "audit event requires a subject"
      end

      def extract_user_id(value, required:)
        if value.nil?
          raise MissingAffectedUserError, "audit event requires an affected user" if required

          return nil
        end

        return value if value.is_a?(Integer)
        return value.id if value.respond_to?(:id)

        raise InvalidPayloadError, "affected_user must be a user or id"
      end

      def subject_snapshot(subject, subject_label)
        label = subject_label.nil? ? nil : subject_label.to_s
        if subject.nil?
          return { subject_type: nil, subject_id: nil, subject_label: label }
        end

        unless subject.respond_to?(:id)
          raise InvalidPayloadError, "subject must provide an id"
        end

        {
          subject_type: subject.class.name,
          subject_id: subject.id,
          subject_label: label
        }
      end

      def normalize_scope_class!(value)
        token = value.to_sym
        normalized = CommandTower::Audit::Event::SCOPE_CLASSES[token]
        unless normalized
          raise InvalidPayloadError,
            "scope_class must be one of #{CommandTower::Audit::Event::SCOPE_CLASSES.keys.join(", ")}"
        end

        normalized
      end

      def normalize_host_context!(host_context, scope_class:)
        host_scope = CommandTower::Audit::Event::SCOPE_CLASSES[:host]
        if scope_class != host_scope
          return { host_context_type: nil, host_context_identifier: nil }
        end

        unless host_context.is_a?(Hash)
          raise InvalidPayloadError, "host_context is required when scope_class is host"
        end

        context_type = host_context[:type] || host_context["type"]
        context_identifier = host_context[:identifier] || host_context["identifier"]
        if context_type.to_s.strip.empty? || context_identifier.to_s.strip.empty?
          raise InvalidPayloadError, "host_context requires type and identifier when scope_class is host"
        end

        {
          host_context_type: context_type.to_s.strip,
          host_context_identifier: context_identifier.to_s.strip
        }
      end
    end
  end
end
