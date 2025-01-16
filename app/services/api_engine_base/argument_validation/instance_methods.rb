# frozen_string_literal: true

module ApiEngineBase::ArgumentValidation
  module InstanceMethods
    def run_validations!
      context.valid_arguments = true

      validate_param!
      validate_compositions!
      continue_with_logical_code!
    end

    def continue_with_logical_code!
      return if @context_validation_failures.nil?

      invalid_argument_keys = @context_validation_failures.keys
      msg = @context_validation_failures.map { |_k, obj| obj[:msg] }.join(", ")
      context.fail!(msg:, invalid_argument_hash: @context_validation_failures, invalid_argument_keys:, invalid_arguments: true)
    end

    def inline_argument_failure!(errors:)
      errors = errors.to_hash
      invalid_argument_keys = errors.keys
      invalid_argument_hash = {}
      human_readable = []

      errors.each do |k, v|
        error_message = Array(v).join(", ")
        invalid_argument_hash[k] = { msg: error_message }
        human_readable << "#{k}: #{error_message}"
      end

      msg = "Invalid arguments: #{human_readable.join(", ")}"
      context.fail!(msg:, invalid_argument_hash:, invalid_argument_keys:, invalid_arguments: true)
    end

    def validate_param!
      self.class.validate_params.each do |metadata|
        value = context.public_send(metadata[:name])
        use_length = metadata[:length]
        if metadata[:required] && value.nil?
          __failed_argument_validation(msg: "Parameter [#{metadata[:name]}] is required but not present", argument: metadata[:name], metadata:)
        end

        if value.nil? && metadata[:default]
          context.public_send(:"#{metadata[:name]}=", metadata[:default])
          next
        elsif value.nil?
          next
        end

        if is_a = metadata[:is_a]
          direct_type = false
          ancestor_type = false

          # Check if direct type of `is_a` Integer === 5 => true
          direct_type = Array(is_a).none? { _1 === value }

          # If it is a direct type, we dont need to do any other type of checking
          if direct_type == true
            lineage = value.ancestors rescue []
            # Check inclusion in ancestor list
            ancestor_type = Array(is_a).none? { lineage.include?(_1) }
          end
          if direct_type && ancestor_type
            __failed_argument_validation(msg: "Parameter [#{metadata[:name]}] must be of type #{is_a}. Given #{value.class} [#{value}]", argument: metadata[:name], metadata:)
          end
        end

        if metadata[:is_one]
          if Array(metadata[:is_one]).none? { _1 == value }
            __failed_argument_validation(msg: "Parameter [#{metadata[:name]}] must be one of #{Array(metadata[:is_one])}. Given #{value}", argument: metadata[:name], metadata:)
          end
        end

        validate_sign!(name: metadata[:name], value:, sign: "lt", validation: metadata[:lte], use_length:, metadata:) { (use_length ? value.length : value) <= _1 }
        validate_sign!(name: metadata[:name], value:, sign: "lte", validation: metadata[:lt], use_length:, metadata:) { (use_length ? value.length : value) < _1 }
        validate_sign!(name: metadata[:name], value:, sign: "eq", validation: metadata[:eq], use_length:, metadata:) { (use_length ? value.length : value) == _1 }
        validate_sign!(name: metadata[:name], value:, sign: "gte", validation: metadata[:gte], use_length:, metadata:) { (use_length ? value.length : value) >= _1 }
        validate_sign!(name: metadata[:name], value:, sign: "gt", validation: metadata[:gt], use_length:, metadata:) { (use_length ? value.length : value) > _1 }
      end
    end

    def validate_compositions!
      self.class.compositions.each do |type, metadata|
        value_list = {}

        metadata[:keys].each do |argument|
          value = context.public_send(argument)
          next if value.nil?

          value_list[argument] = value
        end

        composition_result = metadata[:validation_proc].(value_list.count, value_list.keys)

        next if value_list.count == 0 && !metadata[:required]

        if !composition_result[:is_valid]
          composition_result[:message]
          context.client_composite_error = composition_result[:requirement]
          msg = "Composite Key failure for #{type} [#{metadata[:name]}]. #{composition_result[:message]}. Provided values for the following keys: #{value_list.keys}. Available keys #{metadata[:keys]}"
          __failed_argument_validation(msg:, argument: metadata[:name], metadata: ,error: ApiEngineBase::ServiceBase::CompositionValidationError)
          next
        end

        if metadata[:delegation]
          context.public_send("#{metadata[:name]}=", value_list.first[1])
          context.public_send("#{metadata[:name]}_key=", value_list.first[0])
        end
      end
    end

    def validate_sign!(name:, value:, sign:, validation:, use_length:, metadata:)
      return if validation.nil?
      return if yield(validation)

      __failed_argument_validation(metadata:, msg: "Parameter [#{name}]#{ " lengths" if use_length} must be #{sign} to #{validation}. Given #{value}", argument: name)
    end

    def __failed_argument_validation(msg:, argument:, metadata:, error: ApiEngineBase::ServiceBase::ArgumentValidationError)
      case self.class.on_argument_validation_assigned
      when :raise
        raise error, msg
      when :fail_early
        @context_validation_failures ||= {}
        @context_validation_failures[argument] = {
          msg: msg,
          required: metadata[:requirement],
          is_a: metadata[:is_a],
        }
        # When gracefully failing, it will find all failures first before setting appropriate
        # context variables -- Check out continue_with_logical_code!
      else
        context.invalid_arguments = true
        log_warn(msg)
      end
    end

    def sanitize_params
      self.class.sensitive_params.each do |param|
        next if context.send(param).nil?

        context.send("#{param}=","[FILTERED]")
      end
    end
  end
end
