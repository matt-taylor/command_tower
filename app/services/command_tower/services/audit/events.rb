# frozen_string_literal: true

module CommandTower
  module Services
    module Audit
      module Events
        class List < CommandTower::Services::ApplicationService
          VIEWER_SCOPES = %i[user admin].freeze

          validate :viewer_scope, is_one: VIEWER_SCOPES, required: true
          validate :limit, is_a: Integer, required: true, gte: 1, lte: 100
          validate :offset, is_a: Integer, required: true, gt: -1
          validate :affected_user_id, is_a: Integer, required: false
          validate :actor_user_id, is_a: Integer, required: false
          validate :originating_administrator_id, is_a: Integer, required: false
          validate :actions, is_a: Array, required: false
          validate :subject_types, is_a: Array, required: false
          validate :attribution_mode, is_a: String, required: false
          validate :occurred_after, is_a: [Time, ActiveSupport::TimeWithZone], required: false
          validate :occurred_before, is_a: [Time, ActiveSupport::TimeWithZone], required: false
          validate :principal, is_a: User, required: false
          validate :scope_context, is_a: [CommandTower::AdminScope::ScopeContext, NilClass], required: false

          def call
            if user_scope? && affected_user_id.nil?
              return context.fail!(application_error: CommandTower::Errors::InternalError.new)
            end

            relation = CommandTower::Audit::Event.order(occurred_at: :desc, id: :desc)
            relation = apply_viewer_scope(relation)
            relation = apply_admin_scope(relation)
            relation = apply_present_filters(relation)

            context.events = relation.limit(limit).offset(offset).to_a
            context.pagination = { limit:, offset:, total_count: relation.count }
          end

          private

          def user_scope?
            viewer_scope == :user
          end

          def apply_viewer_scope(relation)
            return relation.where(affected_user_id:, user_history: true) if user_scope?

            relation
          end

          def apply_admin_scope(relation)
            return relation unless admin_scope?

            CommandTower::AdminScope::ApplyAuditScoping.call(
              relation:,
              scope_context:,
              principal: principal || scope_context_principal
            )
          end

          def admin_scope?
            viewer_scope == :admin && scope_context.present?
          end

          def scope_context_principal
            principal
          end

          def apply_present_filters(relation)
            action_list = Array(actions).compact_blank
            relation = relation.where(action: action_list) if action_list.any?
            type_list = Array(subject_types).compact_blank
            relation = relation.where(subject_type: type_list) if type_list.any?
            relation = relation.where(occurred_at: occurred_after..) if occurred_after
            relation = relation.where(occurred_at: ..occurred_before) if occurred_before
            return relation if user_scope?

            relation = relation.where(affected_user_id:) if affected_user_id
            relation = relation.where(actor_user_id:) if actor_user_id
            relation = relation.where(originating_administrator_id:) if originating_administrator_id
            relation = relation.where(attribution_mode:) if attribution_mode.present?
            relation
          end
        end

        class Show < CommandTower::Services::ApplicationService
          VIEWER_SCOPES = %i[user admin].freeze

          validate :viewer_scope, is_one: VIEWER_SCOPES, required: true
          validate :id, is_a: Integer, required: true
          validate :affected_user_id, is_a: Integer, required: false
          validate :principal, is_a: User, required: false
          validate :scope_context, is_a: [CommandTower::AdminScope::ScopeContext, NilClass], required: false

          def call
            if viewer_scope == :user && affected_user_id.nil?
              return context.fail!(application_error: CommandTower::Errors::InternalError.new)
            end

            relation = CommandTower::Audit::Event.where(id:)
            if viewer_scope == :user
              relation = relation.where(affected_user_id:, user_history: true)
            elsif scope_context.present?
              relation = CommandTower::AdminScope::ApplyAuditScoping.call(
                relation:,
                scope_context:,
                principal: principal || scope_context_principal
              )
            end

            event = relation.first
            if event.nil?
              return context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
            end

            context.event = event
          end

          private

          def scope_context_principal
            principal
          end
        end

        class Project < CommandTower::Services::ApplicationService
          validate :event, is_a: CommandTower::Audit::Event, required: true
          validate :viewer, is_one: %i[user admin], required: true

          def call
            changes = duplicate_hash(event.change_set)
            mask_sensitive_changes!(changes)

            context.projection = {
              id: event.id,
              event_name: event.action,
              event_label: registry_label_for(event.action),
              occurred_at: event.occurred_at,
              attribution_mode: event.attribution_mode,
              actor_user_id: event.actor_user_id,
              affected_user_id: event.affected_user_id,
              subject_type: event.subject_type,
              subject_id: event.subject_id,
              subject_label: event.subject_label,
              impersonation_active: event.impersonation_active,
              originating_administrator_id: event.originating_administrator_id,
              changes:,
              metadata: duplicate_hash(event.metadata)
            }
          end

          private

          def registry_label_for(action)
            registry = CommandTower.config.registry.audit
            return "" unless registry.registered?(action)

            registry.fetch(action).label.to_s
          end

          def mask_sensitive_changes!(changes)
            sensitivity_keys.each do |key|
              entry = changes[key] || changes[key.to_sym]
              next unless entry.is_a?(Hash)

              changes.delete(key)
              changes.delete(key.to_sym)
              changes[key] = {
                "from" => CommandTower::Audit::Masking.value(field: key, raw: hash_value(entry, "from")),
                "to" => CommandTower::Audit::Masking.value(field: key, raw: hash_value(entry, "to"))
              }
            end
          end

          def sensitivity_keys
            snapshot = Array(event.sensitive_fields).map(&:to_s)
            snapshot | current_sensitive_fields
          end

          def current_sensitive_fields
            registry = CommandTower.config.registry.audit
            return [] unless registry.registered?(event.action)

            Array(registry.fetch(event.action).sensitive_fields).map(&:to_s)
          end

          def duplicate_hash(value)
            return {} unless value.is_a?(Hash)

            value.deep_dup
          end

          def hash_value(entry, key)
            entry[key] || entry[key.to_sym]
          end
        end
      end
    end
  end
end
