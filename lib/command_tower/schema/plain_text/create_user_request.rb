# frozen_string_literal: true

module CommandTower
  module Schema
    module PlainText
      class CreateUserRequest < JsonSchematize::Generator
        schema_default option: :dig_type, value: :string

        add_field name: :first_name, type: String, required: false
        add_field name: :last_name, type: String, required: false
        add_field name: :username, type: String, required: false
        add_field name: :email, type: String, required: false
        add_field name: :password, type: String, required: false
        add_field name: :password_confirmation, type: String, required: false
      end
    end
  end
end
