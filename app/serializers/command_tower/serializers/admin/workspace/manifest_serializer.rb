# frozen_string_literal: true

module CommandTower
  module Serializers
    module Admin
      module Workspace
        class ManifestSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(tools)
            {
              tools: Array(tools).map do |tool|
                payload = {
                  id: tool.fetch(:id),
                  label: tool.fetch(:label),
                  description: tool.fetch(:description),
                  route: tool.fetch(:route),
                  group: tool.fetch(:group),
                  sortOrder: tool.fetch(:sort_order),
                  icon: tool[:icon]
                }
                payload[:scope] = serialize_scope(tool[:scope]) if tool.key?(:scope)
                payload[:scopeOptions] = serialize_scope_options(tool[:scope_options]) if tool.key?(:scope_options)
                payload[:availability] = serialize_availability(tool[:availability]) if tool.key?(:availability)
                payload
              end
            }
          end

          def self.serialize_scope(scope)
            {
              required: scope.fetch(:required),
              parameter: scope.fetch(:parameter),
              label: scope.fetch(:label)
            }
          end
          private_class_method :serialize_scope

          def self.serialize_scope_options(options)
            Array(options).map do |option|
              {
                value: option.fetch(:value),
                label: option.fetch(:label)
              }
            end
          end
          private_class_method :serialize_scope_options

          def self.serialize_availability(availability)
            {
              enabled: availability.fetch(:enabled),
              reason: availability[:reason]
            }
          end
          private_class_method :serialize_availability
        end
      end
    end
  end
end
