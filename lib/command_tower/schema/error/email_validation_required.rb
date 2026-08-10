# frozen_string_literal: true

require "json_schematize/generator"

module CommandTower
  module Schema
    module Error
      class EmailValidationRequired < JsonSchematize::Generator
        add_field name: :status, type: String
        add_field name: :message, type: String
        add_field name: :meta, type: Hash
      end
    end
  end
end
