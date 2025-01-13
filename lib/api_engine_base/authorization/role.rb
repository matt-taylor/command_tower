# frozen_string_literal: true

module ApiEngineBase
  module Authorization
    class Role
      class << self
        def create_role(name:, description:, entities: nil, allow_everything: false)
          if roles[name]
            raise Error, "Role [#{name}] already exists. Must use different name"
          end

          if allow_everything
            Rails.logger.info { "Authorization Role: #{name} is granted authorization to all roles" }
          else
            unless Array(entities).all? { Entity === _1 }
              raise Error, "Parameter :entities must include objects of or inherited by ApiEngineBase::Authorization::Entity"
            end
          end

          roles[name] = new(name:, description:, entities:, allow_everything:)
          # A role is `intended` to be immutable (attr_reader)
          # Once the role is defined it will not get changed
          # After it is created, add the mapping to the source of truth list of mapped method names to their controllers
          ApiEngineBase::Authorization.add_mapping!(role: roles[name])

          roles[name]
        end

        def roles
          @roles ||= ActiveSupport::HashWithIndifferentAccess.new
        end

        def roles_reset!
          @roles = ActiveSupport::HashWithIndifferentAccess.new
        end
      end

      attr_reader :entities, :name, :description, :allow_everything
      def initialize(name:, description:, entities:, allow_everything: false)
        @name = name
        @entities = Array(entities)
        @description = description
        @allow_everything = allow_everything
      end

      def authorized?(controller:, method:, user:)
        return_value = { role: name, description: }
        return return_value.merge(authorized: true, reason: "#{name} allows all authorizations") if allow_everything

        matched_controllers = controller_entity_mapping[controller]
        # if Role does not match any of the controllers
        # explicitly return nil here to ensure upstream knows this role does not care about the route
        return return_value.merge(authorized: nil, reason: "#{name} does not match") if matched_controllers.nil?

        rejected_entities = matched_controllers.map do |entity|
          case entity.matches?(controller:, method:)
          when false, nil
            { authorized: false, entity: entity.name, controller:, readable: entity.humanize, status: "Rejected by inclusion" }
          when true
            # Entity matches all inclusions
            if entity.authorized?(user:)
              # Do nothing! Entity has authorized the user
            else
              { authorized: false, entity: entity.name, controller:, readable: entity.humanize, status: "Rejected via custom Entity Authorization" }
            end
          end
        end.compact

        # If there were no entities that rejected authorization, return authorized
        return return_value.merge(authorized: true, reason: "All entities approve authorization") if rejected_entities.empty?

        return_value.merge(authorized: false, reason: "Subset of Entities Rejected authorization", rejected_entities:)
      end

      def guards
        mapping = {}
        controller_entity_mapping.each do |controller, entities|
          mapping[controller] ||= []
          entities.map do |entity|
            if entity.only
              # We only care about these methods on the controller
              mapping[controller] += entity.only
            elsif entity.except
              # We care about all methods on the controller except these
              mapping[controller] += controller.instance_methods(false) - entity.except
            else
              # We care about all methods on the controller
              mapping[controller] += controller.instance_methods(false)
            end
          end
        end

        mapping
      end

      def controller_entity_mapping
        @controller_entity_mapping ||= @entities.group_by(&:controller)
      end
    end
  end
end
