# frozen_string_literal: true

require "command_tower/schema/shared/user"

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Modify
          class Response < JsonSchematize::Generator
            add_field name: :created_by, type: CommandTower::Schema::Shared::User
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
