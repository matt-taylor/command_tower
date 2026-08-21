# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module AdminWorkspace
        class ToolDefinition
          include ClassComposer::Generator

          ROUTE = %r{\A/admin(/[a-z][a-z0-9_-]*)+\z}

          DESCRIPTION_MAX_LENGTH = 160

          add_composer :label,
            desc: "Human-readable tool name for dashboard and navigation",
            allowed: String,
            default: ""

          add_composer :description,
            desc: "Short launcher blurb: what the tool does (presentation only; soft target ≤100 chars)",
            allowed: String,
            default: ""

          add_composer :route,
            desc: "Frontend Admin Workspace path (navigation metadata, not an engine API path)",
            allowed: String,
            default: ""

          add_composer :group,
            desc: "Presentation group token (open set; domain-blind)",
            allowed: [String, Symbol],
            default: ""

          add_composer :sort_order,
            desc: "Order within and across groups (lower first)",
            allowed: Integer,
            default: 0

          add_composer :required_entity,
            desc: "RBAC entity name required for this tool to appear in the manifest",
            allowed: [String, Symbol],
            default: ""

          add_composer :icon,
            desc: "Optional icon token for the shared frontend",
            allowed: [String, Symbol, NilClass],
            default: nil

          add_composer :scope_required,
            desc: "When true, admin requests for this tool require a host scope parameter",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :scope_parameter,
            desc: "Transport parameter name for the host scope value (snake_case token)",
            allowed: String,
            default: ""

          add_composer :scope_label,
            desc: "Human-readable label for the scope picker",
            allowed: String,
            default: ""

          attr_accessor :owner, :id

          def scope_required?
            scope_required == true
          end

          def validate_definition!(name:)
            self.id = name.to_s
            self.owner = owner&.to_sym || :host
            self.label = require_present_string!(label, field: "label", name:)
            self.description = normalize_description!(name:)
            self.route = require_route!(name:)
            self.group = require_segment!(group, field: "group", name:)
            self.required_entity = require_segment!(required_entity, field: "required_entity", name:)
            self.icon = normalize_icon!(name:)
            normalize_scope!(name:)
            unless sort_order.is_a?(Integer)
              raise CommandTower::AdminWorkspace::InvalidToolDefinitionError,
                "admin workspace tool #{name} has invalid sort_order #{sort_order.inspect}"
            end
          end

          private

          def normalize_description!(name:)
            text = description.to_s.strip
            if text.length > DESCRIPTION_MAX_LENGTH
              raise CommandTower::AdminWorkspace::InvalidToolDefinitionError,
                "admin workspace tool #{name} description exceeds #{DESCRIPTION_MAX_LENGTH} characters"
            end

            text
          end

          def require_present_string!(value, field:, name:)
            text = value.to_s.strip
            if text.empty?
              raise CommandTower::AdminWorkspace::InvalidToolDefinitionError,
                "admin workspace tool #{name} is missing #{field}"
            end

            text
          end

          def require_route!(name:)
            path = require_present_string!(route, field: "route", name:)
            unless path.match?(ROUTE)
              raise CommandTower::AdminWorkspace::InvalidToolDefinitionError,
                "admin workspace tool #{name} has invalid route #{path.inspect}"
            end

            path
          end

          def require_segment!(value, field:, name:)
            token = value.to_s.strip
            unless token.match?(CommandTower::Events::SEGMENT)
              raise CommandTower::AdminWorkspace::InvalidToolDefinitionError,
                "admin workspace tool #{name} has invalid #{field} #{value.inspect}"
            end

            token
          end

          def normalize_icon!(name:)
            return if icon.nil? || icon.to_s.strip.empty?

            require_segment!(icon, field: "icon", name:)
          end

          def normalize_scope!(name:)
            if scope_required?
              self.scope_parameter = require_segment!(scope_parameter, field: "scope_parameter", name:)
              self.scope_label = require_present_string!(scope_label, field: "scope_label", name:)
              return
            end

            self.scope_parameter = ""
            self.scope_label = ""
          end
        end
      end
    end
  end
end
