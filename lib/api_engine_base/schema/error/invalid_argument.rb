# frozen_string_literal: true

module ApiEngineBase
  module Schema
    module Error
      class InvalidArgument < JsonSchematize::Generator
        add_field name: :schema, type: JsonSchematize::Generator, required: true, converter: ->(val) { val }
        add_field name: :argument, type: String, required: true
        add_field name: :argument_type, type: String, required: true
        add_field name: :reason, type: String
      end
    end
  end
end

