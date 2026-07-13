# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module PasswordForgot
          module Send
            class Request < JsonSchematize::Generator
              schema_default option: :dig_type, value: :string

              add_field name: :email, type: String, required: true
            end
          end
        end
      end
    end
  end
end
