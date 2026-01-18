# frozen_string_literal: true

require "command_tower/schema/shared/user"

module CommandTower
  module Schema
    module Entities
      module Inbox
        class MessageBlastEntity < JsonSchematize::Generator
          add_field name: :created_by, type: CommandTower::Schema::Shared::User, required: false # to allow metadata call to be fast
          add_field name: :text, type: String, required: false # to allow metadata call to be fast
          add_field name: :title, type: String
          add_field name: :id, type: Integer
          add_field name: :existing_users, type: JsonSchematize::Boolean
          add_field name: :new_users, type: JsonSchematize::Boolean
        end
      end
    end
  end
end
