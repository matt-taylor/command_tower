# frozen_string_literal: true

require "api_engine_base/schema/error/invalid_argument"

module ApiEngineBase
  module Schema
    module Error
      class InvalidArgumentResponse < JsonSchematize::Generator
        add_field name: :message, type: String, required: true
        add_field name: :status, type: String, required: true
        add_field name: :invalid_arguments, array_of_types: true, type: InvalidArgument
        add_field name: :invalid_argument_keys,  type: Array
      end
    end
  end
end

