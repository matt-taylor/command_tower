# frozen_string_literal: true

require "command_tower/configuration/registry/audit/event_definition"

module CommandTower
  module Configuration
    module Registry
      module Audit
        class Config
          PLATFORM_EVENTS = {
            user_registered: {
              label: "User registered",
              tags: %w[identity account registration],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            role_assigned: {
              label: "Role assigned",
              tags: %w[identity rbac authorization],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[role],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            role_revoked: {
              label: "Role revoked",
              tags: %w[identity rbac authorization],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[role],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            password_changed: {
              label: "Password changed",
              tags: %w[identity password security],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            email_verified: {
              label: "Email verified",
              tags: %w[identity verification email],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            admin_user_name_changed: {
              label: "Admin user name changed",
              tags: %w[identity admin users],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[first_name last_name],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            admin_user_username_changed: {
              label: "Admin user username changed",
              tags: %w[identity admin users],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[username],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            admin_user_email_changed: {
              label: "Admin user email changed",
              tags: %w[identity admin users email],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            admin_user_email_validation_changed: {
              label: "Admin user email validation changed",
              tags: %w[identity admin users verification email],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[email_validated],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            phone_updated: {
              label: "Phone updated",
              tags: %w[identity phone profile],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: %i[phone],
              allowed_changes: %i[phone],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            phone_cleared: {
              label: "Phone cleared",
              tags: %w[identity phone profile],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: %i[phone],
              allowed_changes: %i[phone],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            phone_verified: {
              label: "Phone verified",
              tags: %w[identity verification phone],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            announcement_produced: {
              label: "Announcement produced",
              tags: %w[messaging announcement admin],
              enabled: true,
              enablement_configurable: false,
              user_history: false,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: false,
              affected_user_required: false
            },
            session_created: {
              label: "Session created",
              tags: %w[authentication session security],
              enabled: true,
              enablement_configurable: true,
              user_history: false,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :ninety_days,
              subject_required: false,
              affected_user_required: true
            },
            session_cleared: {
              label: "Session cleared",
              tags: %w[authentication session security],
              enabled: false,
              enablement_configurable: true,
              user_history: false,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :ninety_days,
              subject_required: false,
              affected_user_required: true
            },
            login_failed: {
              label: "Login failed",
              tags: %w[authentication login security],
              enabled: false,
              enablement_configurable: true,
              user_history: false,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :ninety_days,
              subject_required: false,
              affected_user_required: false
            },
            impersonation_started: {
              label: "Impersonation started",
              tags: %w[authentication impersonation security],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: [],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            },
            impersonation_ended: {
              label: "Impersonation ended",
              tags: %w[authentication impersonation security],
              enabled: true,
              enablement_configurable: false,
              user_history: true,
              sensitive_fields: [],
              allowed_changes: %i[reason],
              retention: :permanent,
              subject_required: true,
              subject_type: "User",
              affected_user_required: true,
              global_visible_in_host_scope: true
            }
          }.freeze

          def initialize
            @definitions = {}
            @finalized = false
            seed_platform_events!
          end

          def event(name, owner: :host)
            raise CommandTower::Audit::FrozenRegistryError, "audit registry is frozen" if @finalized

            normalized = normalize_name!(name)
            existing = @definitions[normalized]
            if existing
              if existing.owner == :command_tower && owner == :host
                raise CommandTower::Audit::HostOverrideError,
                  "host cannot redefine CommandTower-owned audit event #{normalized}"
              end

              raise CommandTower::Audit::DuplicateEventError,
                "audit event #{normalized} is already registered"
            end

            definition = EventDefinition.new
            yield definition if block_given?
            definition.owner = owner
            definition.validate_policy!(name: normalized)
            @definitions[normalized] = definition
            definition
          end

          def set_enabled!(name, value)
            raise CommandTower::Audit::FrozenRegistryError, "audit registry is frozen" if @finalized
            unless [true, false].include?(value)
              raise CommandTower::Audit::InvalidEventDefinitionError, "enabled must be true or false"
            end

            definition = fetch(name)
            if definition.owner != :command_tower
              raise CommandTower::Audit::HostOverrideError,
                "set_enabled! is only for CommandTower-owned audit events"
            end
            unless definition.enablement_configurable?
              raise CommandTower::Audit::EnablementNotConfigurableError,
                "audit event #{normalize_name!(name)} enablement is not configurable"
            end

            definition.enabled = value
            definition
          end

          def fetch(name)
            normalized = normalize_name!(name)
            definition = @definitions[normalized]
            if definition.nil?
              raise CommandTower::Audit::UnregisteredEventError,
                "audit event #{normalized} is not registered"
            end

            definition
          end

          def registered?(name)
            @definitions.key?(normalize_name!(name))
          rescue CommandTower::Audit::InvalidEventNameError
            false
          end

          def definitions
            @definitions.dup.freeze
          end

          def finalize!
            @definitions.each_value do |definition|
              next unless definition.respond_to?(:class_composer_freeze_objects!)

              definition.class_composer_freeze_objects!(behavior: :raise, children: true)
            end
            @definitions.freeze
            @finalized = true
            self
          end

          def finalized?
            @finalized
          end

          def reset_host_definitions!
            thaw_for_test!
            @definitions.delete_if { |_name, definition| definition.owner == :host }
            restore_platform_enablement!
            self
          end

          private

          def seed_platform_events!
            PLATFORM_EVENTS.each do |name, attrs|
              event(name, owner: :command_tower) do |definition|
                definition.enabled = attrs[:enabled]
                definition.enablement_configurable = attrs.fetch(:enablement_configurable, false)
                definition.user_history = attrs[:user_history]
                definition.sensitive_fields = attrs[:sensitive_fields]
                definition.allowed_changes = attrs[:allowed_changes]
                definition.retention = attrs[:retention]
                definition.subject_required = attrs[:subject_required]
                definition.affected_user_required = attrs[:affected_user_required]
                definition.label = attrs.fetch(:label, "")
                definition.tags = attrs.fetch(:tags, [])
                definition.subject_type = attrs.fetch(:subject_type, "")
                definition.global_visible_in_host_scope = attrs.fetch(:global_visible_in_host_scope, false)
              end
            end
          end

          def restore_platform_enablement!
            PLATFORM_EVENTS.each_key { |name| @definitions.delete(name.to_s) }
            seed_platform_events!
          end

          def thaw_for_test!
            return unless @finalized || @definitions.frozen?

            @definitions = @definitions.dup
            @finalized = false
          end

          def normalize_name!(name)
            raise CommandTower::Audit::InvalidEventNameError, "audit event name is required" if name.nil? || name.to_s.strip.empty?

            segments = name.to_s.split(".")
            raise CommandTower::Audit::InvalidEventNameError, "audit event name is required" if segments.empty?

            normalized = segments.map do |segment|
              unless segment.match?(CommandTower::Events::SEGMENT)
                raise CommandTower::Audit::InvalidEventNameError,
                  "invalid audit event name #{name.inspect}"
              end

              segment
            end

            normalized.join(".")
          end
        end
      end
    end
  end
end
