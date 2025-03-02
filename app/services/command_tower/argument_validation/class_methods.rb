# frozen_string_literal: true

module CommandTower::ArgumentValidation
  module ClassMethods
    ON_ARGUMENT_VALIDATION = [
      DEFAULT_VALIDATION = :raise,
      :fail_early,
      :log,
    ]

    def on_argument_validation_assigned
      @on_argument_validation ||= DEFAULT_VALIDATION
    end

    def on_argument_validation(set)
      raise "Must be one of #{ON_ARGUMENT_VALIDATION}" unless ON_ARGUMENT_VALIDATION.include?(set)

      @on_argument_validation = set
    end

    def compose_exact(count, name, required:, delegation: false, &block)
      raise CommandTower::ServiceBase::CompositionValidationError, "Count must be greater than 0" if count < 1

      validation_proc = Proc.new do |input_count, keys|
        language = (input_count > 0) ? "But #{input_count} keys were assigned" : "But no key was assigned"
        {
          message: "Expected [#{count}] of the keys to have a value assigned. #{language}",
          is_valid: (input_count == count),
          requirement: "Exactly #{count} key(s) of #{keys} must be provided.",
        }
      end

      composition_validation_proc = Proc.new do
        keys = compositions[__stacked_type.last[:name]][:keys]
        if keys.length < count
          raise CommandTower::ServiceBase::CompositionValidationError, "Composition configuration error. Key [#{name}] expects EXACTLY #{count} keys to create an instance. Only #{keys.length} is provided for the composition. Please add more keys or reduce the expectation"
        end
      end
      composition(name:, type: :compose_exact, required:, delegation:, composition_validation_proc:, validation_proc:, &block)
    end

    def at_most(count, name, required:, &block)
      raise CommandTower::ServiceBase::CompositionValidationError, "Count must be greater than 0" if count < 1

      validation_proc = Proc.new do |input_count, keys|
        {
          message: "Expected at most #{count} keys assigned",
          is_valid: (input_count <= count),
          requirement: "Validation Error: At most #{count} key(s) of #{keys} can be provided.",
        }
      end

      composition(name:, type: :at_most, required:, delegation: false, validation_proc:, &block)
    end

    def at_least(count, name, required:, &block)
      raise CommandTower::ServiceBase::CompositionValidationError, "Count must be greater than 0" if count < 1

      validation_proc = Proc.new do |input_count, keys|
        {
          message: "Expected at least #{count} keys assigned. Available keys",
          is_valid: (input_count >= count),
          requirement: "Validation Error: At least #{count} key(s) of #{keys} must be provided.",
        }
      end

      composition_validation_proc = Proc.new do
        keys = compositions[__stacked_type.last[:name]][:keys]
        if keys.length < count
          raise CommandTower::ServiceBase::CompositionValidationError, "Composition configuration error. Key [#{name}] expects AT LEAST #{count} keys to create an instance. Only #{keys.length} is provided for the composition. Please add more keys or reduce the expectation"
        end
      end
      composition(name:, type: :at_least, required:, delegation: false, composition_validation_proc:, validation_proc:, &block)
    end

    def at_least_one(name, required:, &block)
      at_least(1, name, required:, &block)
    end

    def one_of(name, required:, delegation: true, &block)
      compose_exact(1, name, required:, delegation:, &block)
    end

    def composition(name:, type:, required:, delegation:, validation_proc:, composition_validation_proc: nil, &block)
      compositions[name] ||= { type:, name:, keys: [], required:, delegation:, validation_proc: }
      if __stacked_type.map { _1[:type] }.include?(type)
        raise CommandTower::ServiceBase::NestedDuplicateTypeError, "Duplicate Nested type's are not allowed. #{type} composition was included more than once"
      end

      __stacked_type << { type:, name: }

      yield

      if composition_validation_proc
        composition_validation_proc.()
      end

      if __existing_names.include?(name)
        raise CommandTower::ServiceBase::NameConflictError, "Name conflict for #{name}. Duplicated as a key"
      end

      __existing_names << name
      # returning from the yield...pop it from the stack.
      # This allows us to know the current depth of where we are in the nested stack
      __stacked_type.pop

      if delegation
        delegate name, to: :context
        delegate :"#{name}_key", to: :context
      end
    end

    def validate(name, default: nil, length: false, is_a: nil, is_one: nil, lt: nil, lte: nil, eq: nil, gt: nil, gte: nil, delegation: true, sensitive: false, required: false)
      if __existing_names.include?(name)
        raise CommandTower::ServiceBase::NameConflictError, "Duplicate key name found. [#{name}] can only be defined once"
      end

      __existing_names << name

      if default
        if is_a
          if Array(is_a).none? { _1 === default }
            raise CommandTower::ServiceBase::DefaultValueError, "Default value provided [#{default}] does not match any `is_a` value(s) of #{is_a}."
          end
        end

        if is_one
          if Array(is_one).none? { _1 == default }
            raise CommandTower::ServiceBase::DefaultValueError, "Default value provided [#{default}] does not match any `is_one` value(s) of #{is_one}."
          end
        end
      end

      if __stacked_type.length > 0
        compositions[__stacked_type.last[:name]][:keys] << name
      end

      validate_params << {
        name:,
        is_a:,
        lt:,
        lte:,
        eq:,
        gt:,
        gte:,
        length:,
        required:,
        is_one:,
        default:,
      }
      sensitive_params << name if sensitive

      if delegation
        delegate name, to: :context
      end
    end

    def sensitive_params
      @sensitive_params ||= []
    end

    def validate_params
      @validate_params ||= []
    end

    def compositions
      @compositions ||= {}
    end

    def __stacked_type
      @__stacked_type ||= []
    end

    def __existing_names
      @__existing_names ||= []
    end
  end
end
