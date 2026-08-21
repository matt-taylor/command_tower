# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module Audit
        class EventDefinition
          include ClassComposer::Generator

          RETENTIONS = %i[permanent ninety_days one_year].freeze

          add_composer :enabled,
            desc: "When false, audit(...) does not emit a notification",
            allowed: [TrueClass, FalseClass],
            default: true

          add_composer :enablement_configurable,
            desc: "When true, hosts may change only the enabled setting for this CommandTower-owned event",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :user_history,
            desc: "Whether this event type may appear in account history (query enforcement is later)",
            allowed: [TrueClass, FalseClass],
            default: true

          add_composer :sensitive_fields,
            desc: "Registered field names that later projections must treat as sensitive",
            allowed: Array,
            default: []

          add_composer :allowed_changes,
            desc: "Allowlisted keys for the runtime changes hash",
            allowed: Array,
            default: []

          add_composer :retention,
            desc: "Retention intent seam (enforcement is later)",
            allowed: Symbol,
            default: :permanent

          add_composer :subject_required,
            desc: "When true, audit(...) must supply a subject",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :affected_user_required,
            desc: "When true, audit(...) must supply an affected user",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :label,
            desc: "Optional human-readable display label for Explorer UI (empty falls back to event name)",
            allowed: String,
            default: ""

          add_composer :tags,
            desc: "Discovery tags for filter-option selectors (presentation only; not ledger/authz)",
            allowed: Array,
            default: []

          add_composer :subject_type,
            desc: "Optional canonical subject class name for Explorer Resource catalogs (empty = none)",
            allowed: String,
            default: ""

          add_composer :global_visible_in_host_scope,
            desc: "When true, global-scoped events may appear in host-scoped admin audit views for affected users in scope",
            allowed: [TrueClass, FalseClass],
            default: false

          attr_accessor :owner

          def enabled?
            enabled == true
          end

          def enablement_configurable?
            enablement_configurable == true
          end

          def global_visible_in_host_scope?
            global_visible_in_host_scope == true
          end

          def validate_policy!(name:)
            unless RETENTIONS.include?(retention.to_sym)
              raise CommandTower::Audit::InvalidEventDefinitionError,
                "audit event #{name} has invalid retention #{retention.inspect} " \
                "(allowed: #{RETENTIONS.join(", ")})"
            end

            normalized_allowed = normalize_field_list!(allowed_changes, field: "allowed_changes", name:)
            normalized_sensitive = normalize_field_list!(sensitive_fields, field: "sensitive_fields", name:)
            extra_sensitive = normalized_sensitive - normalized_allowed
            if extra_sensitive.any?
              raise CommandTower::Audit::InvalidEventDefinitionError,
                "audit event #{name} sensitive_fields #{extra_sensitive.inspect} " \
                "must be included in allowed_changes"
            end

            self.allowed_changes = normalized_allowed
            self.sensitive_fields = normalized_sensitive
            self.tags = normalize_tags!(tags, name:)
            self.subject_type = normalize_subject_type!(subject_type, name:)
            self.retention = retention.to_sym
            self.owner = owner&.to_sym || :host
          end

          def normalize_field_list!(values, field:, name:)
            Array(values).map do |value|
              segment = value.to_s
              unless segment.match?(CommandTower::Events::SEGMENT)
                raise CommandTower::Audit::InvalidEventDefinitionError,
                  "audit event #{name} #{field} contains invalid token #{value.inspect}"
              end

              segment.to_sym
            end
          end

          # Lowercase, stripped, unique, deterministic. Rejects blank / invalid tokens.
          def normalize_tags!(values, name:)
            Array(values).filter_map do |value|
              tag = value.to_s.strip.downcase
              next if tag.empty?

              unless tag.match?(/\A[a-z0-9_]+\z/)
                raise CommandTower::Audit::InvalidEventDefinitionError,
                  "audit event #{name} tags contains invalid token #{value.inspect}"
              end

              tag
            end.uniq.sort
          end

          SUBJECT_TYPE = /\A[A-Z][A-Za-z0-9_:]*\z/

          def normalize_subject_type!(value, name:)
            token = value.to_s.strip
            return "" if token.empty?
            unless SUBJECT_TYPE.match?(token)
              raise CommandTower::Audit::InvalidEventDefinitionError,
                "audit event #{name} subject_type is invalid #{value.inspect}"
            end

            token
          end
        end
      end
    end
  end
end
