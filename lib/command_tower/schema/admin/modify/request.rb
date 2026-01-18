# frozen_string_literal: true

module CommandTower
  module Schema
    module Admin
      module Modify
        class Request < JsonSchematize::Generator
          schema_default option: :dig_type, value: :string

          add_field name: :user_id, type: Integer, required: true
          add_field name: :email, type: String, required: false
          add_field name: :email_validated, type: JsonSchematize::Boolean, required: false
          add_field name: :first_name, type: String, required: false
          add_field name: :last_name, type: String, required: false
          add_field name: :username, type: String, required: false
          add_field name: :verifier_token, type: JsonSchematize::Boolean, required: false
        end
      end
    end
  end
end
