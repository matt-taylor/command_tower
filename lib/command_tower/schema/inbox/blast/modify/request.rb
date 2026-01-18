# frozen_string_literal: true

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Modify
          class Request < JsonSchematize::Generator
            add_field name: :existing_users, type: JsonSchematize::Boolean
            add_field name: :new_users, type: JsonSchematize::Boolean
            add_field name: :title, type: String
            add_field name: :text, type: String
            add_field name: :id, type: Integer, required: false
          end
        end
      end
    end
  end
end
