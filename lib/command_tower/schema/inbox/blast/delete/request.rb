# frozen_string_literal: true

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Delete
          class Request < JsonSchematize::Generator
            schema_default option: :dig_type, value: :string

            add_field name: :id, type: Integer, required: false
          end
        end
      end
    end
  end
end
