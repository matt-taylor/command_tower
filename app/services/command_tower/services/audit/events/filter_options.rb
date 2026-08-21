# frozen_string_literal: true

module CommandTower
  module Services
    module Audit
      module Events
        # Projects safe filter-option metadata from the finalized audit registry.
        # Not authorization — scoped catalogs only (Admin vs Me user_history).
        class FilterOptions < CommandTower::Services::ApplicationService
          ATTRIBUTION_MODE_LABELS = {
            "self_service" => "Self-service",
            "admin_direct" => "Admin action",
            "impersonation" => "Impersonation",
            "system" => "System"
          }.freeze

          validate :viewer_scope, is_a: Symbol, required: true

          def call
            unless %i[admin me].include?(viewer_scope)
              raise CommandTower::Errors::ValidationError, "viewer_scope must be :admin or :me"
            end

            context.event_names = project_event_names
            context.subject_types = project_subject_types
            context.attribution_modes = project_attribution_modes
          end

          private

          def scoped_definitions
            definitions = CommandTower.config.registry.audit.definitions
            if viewer_scope == :admin
              definitions
            else
              definitions.select { |_name, definition| definition.user_history == true }
            end
          end

          def project_event_names
            scoped_definitions.sort_by { |name, _| name }.map do |name, definition|
              label = definition.label.to_s.strip
              label = name if label.empty?
              {
                value: name,
                label:,
                tags: Array(definition.tags)
              }
            end
          end

          def project_subject_types
            scoped_definitions.filter_map do |_name, definition|
              token = definition.subject_type.to_s.strip
              next if token.empty?

              { value: token, label: token }
            end.uniq { |entry| entry[:value] }.sort_by { |entry| entry[:value] }
          end

          def project_attribution_modes
            return [] unless viewer_scope == :admin

            CommandTower::Audit::Event::ATTRIBUTION_MODES.map do |mode|
              {
                value: mode,
                label: ATTRIBUTION_MODE_LABELS.fetch(mode, mode.tr("_", " ").split.map(&:capitalize).join(" "))
              }
            end
          end
        end
      end
    end
  end
end
