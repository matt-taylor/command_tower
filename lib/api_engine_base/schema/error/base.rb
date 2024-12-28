# frozen_string_literal: true

require "json_schematize/generator"

module ApiEngineBase
  module Schema
    module Error
      class Base < JsonSchematize::Generator
        add_field name: :status, type: String
        add_field name: :message, type: String
      end
    end
  end
end

