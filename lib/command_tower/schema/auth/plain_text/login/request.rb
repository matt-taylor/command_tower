# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module Login
          class Request < JsonSchematize::Generator
            schema_default option: :dig_type, value: :string

            add_field name: :identifier, type: String, required: false
            add_field name: :password, type: String, required: false
          end
        end
      end
    end
  end
end
