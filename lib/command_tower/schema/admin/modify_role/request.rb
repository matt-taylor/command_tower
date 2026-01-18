# frozen_string_literal: true

module CommandTower
  module Schema
    module Admin
      module ModifyRole
        class Request < JsonSchematize::Generator
          schema_default option: :dig_type, value: :string

          add_field name: :user_id, type: Integer, required: true
          add_field name: :roles, type: Array, required: false
        end
      end
    end
  end
end
