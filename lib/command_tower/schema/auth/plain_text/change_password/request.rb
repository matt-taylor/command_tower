# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module ChangePassword
          class Request < JsonSchematize::Generator
            schema_default option: :dig_type, value: :string

            add_field name: :current_password, type: String, required: true
            add_field name: :password, type: String, required: true
            add_field name: :password_confirmation, type: String, required: true
          end
        end
      end
    end
  end
end
