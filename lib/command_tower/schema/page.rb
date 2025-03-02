# frozen_string_literal: true

module CommandTower
  module Schema
    class Page < JsonSchematize::Generator
      schema_default option: :dig_type, value: :string

      add_field name: :count, type: Integer
      add_field name: :cursor, type: Integer
      add_field name: :limit, type: Integer
      add_field name: :next, type: String
    end
  end
end
