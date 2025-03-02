# frozen_string_literal: true

require "command_tower/schema/error/invalid_argument"

module CommandTower
  module Schema
    module Error
      class InvalidArgumentResponse < JsonSchematize::Generator
        add_field name: :message, type: String, required: true
        add_field name: :status, type: String, required: true
        add_field name: :invalid_arguments, array_of_types: true, type: InvalidArgument
        add_field name: :invalid_argument_keys, type: Array
      end
    end
  end
end

