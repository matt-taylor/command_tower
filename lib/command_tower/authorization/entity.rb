# frozen_string_literal: true

module CommandTower
  module Authorization
    class Entity
      class << self
        def create_entity(name:, controller:, only: nil, except: nil, source: :host)
          if entities[name]
            raise Error, "Authorization entity [#{name}] already exists. Hosts must not redefine CommandTower-owned entities."
          end

          entity = new(name:, controller:, only:, except:, source:)

          if source.to_sym == :host
            ct_controllers = entities.values.select { |existing| existing.source == :command_tower }.map(&:controller)
            if ct_controllers.include?(entity.controller)
              raise Error, "Host entity [#{name}] redefines CommandTower-owned controller [#{entity.controller}]"
            end
          end

          entities[name] = entity
          entities[name]
        end

        def entities
          @entities ||= ActiveSupport::HashWithIndifferentAccess.new
        end

        def entities_reset!
          @entities = ActiveSupport::HashWithIndifferentAccess.new
        end
      end

      attr_reader :name, :controller, :only, :except, :source
      def initialize(name:, controller:, only: nil, except: nil, source: :host)
        @controller = controller
        @except = except.nil? ? nil : Array(except).map(&:to_sym)
        @only = only.nil? ? nil : Array(only).map(&:to_sym)
        @source = source.to_sym
        @name = name

        validate!
      end

      def humanize
        "name:[#{name}]; controller:[#{controller}]; only:[#{only}]; except:[#{except}]"
      end

      # controller will be the class object
      # method will be the string of the route method
      def matches?(controller:, method:)
        # Return early if the controller does not match the existing entity controller
        return nil if @controller != controller

        # We are in the correct controller

        # if inclusions are not present, the check is on the entire contoller and we can return true
        if only.nil? && except.nil?
          return true
        end

        ## `only` or `except` is present at this point
        if only
          # If method is included in only, accept otherwise return reject
          return only.include?(method.to_sym)
        else
          # If method is included in except, reject otherwise return accept
          return !except.include?(method.to_sym)
        end
      end

      # This is a custom method that can get overridden by a child class for custom
      # authorization logic beyond grouping
      def authorized?(user:)
        true
      end

      private

      def validate!
        if @only && @except
          raise Error, "kwargs `only` and `except` passed in. At most 1 can be passed in."
        end

        validate_controller!
        validate_methods!(@only, :only)
        validate_methods!(@except, :except)
      end

      def validate_controller!
        return true if Class === @controller

        @controller = @controller.constantize
      rescue NameError => e
        raise Error, "Controller [#{@controller}] was not found. Please validate spelling or ensure it is loaded earlier"
      end

      def validate_methods!(array_of_methods, string)
        return if array_of_methods.nil?

        missing_methods = array_of_methods.select do |method|
          !@controller.instance_methods.include?(method)
        end

        return true if missing_methods.empty?

        raise Error, "#{string} parameter is invalid. Controller [#{@controller}] is missing methods:[#{missing_methods}]"
      end
    end
  end
end
