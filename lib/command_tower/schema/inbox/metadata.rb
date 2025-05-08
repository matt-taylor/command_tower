# frozen_string_literal: true

require "command_tower/schema/inbox/message_entity"
require "command_tower/schema/pagination"

module CommandTower
  module Schema
    module Inbox
      class Metadata < JsonSchematize::Generator
        # schema_default option: :dig_type, value: :string

        add_field name: :entities, array_of_types: true, type: CommandTower::Schema::Inbox::MessageEntity, required: false
        add_field name: :count, type: Integer
        add_field name: :pagination, type: CommandTower::Schema::Pagination, required: false
      end
    end
  end
end
