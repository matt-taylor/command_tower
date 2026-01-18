# frozen_string_literal: true

require "command_tower/schema/shared/user"
require "command_tower/schema/shared/pagination"

module CommandTower
  module Schema
    module Shared
      module Admin
        class Users < JsonSchematize::Generator
          add_field name: :users, array_of_types: true, type: CommandTower::Schema::Shared::User
          add_field name: :count, type: Integer, required: false
          add_field name: :pagination, type: CommandTower::Schema::Shared::Pagination, required: false
        end
      end
    end
  end
end
