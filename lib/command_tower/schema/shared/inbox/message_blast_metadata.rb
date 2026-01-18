# frozen_string_literal: true

require "command_tower/schema/entities/inbox/message_blast_entity"
require "command_tower/schema/shared/pagination"

module CommandTower
  module Schema
    module Shared
      module Inbox
        class MessageBlastMetadata < JsonSchematize::Generator
          add_field name: :entities, array_of_types: true, type: CommandTower::Schema::Entities::Inbox::MessageBlastEntity, required: false
          add_field name: :count, type: Integer
          add_field name: :pagination, type: CommandTower::Schema::Shared::Pagination, required: false
        end
      end
    end
  end
end
