# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module PasswordForgot
          module Reset
            class Request < JsonSchematize::Generator
              schema_default option: :dig_type, value: :string

              add_field name: :token, type: String, required: true
              add_field name: :email, type: String, required: false
              add_field name: :password, type: String, required: true
              add_field name: :password_confirmation, type: String, required: true
            end
          end
        end
      end
    end
  end
end
