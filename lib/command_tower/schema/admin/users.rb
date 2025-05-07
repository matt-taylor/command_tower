# frozen_string_literal: true

require "command_tower/schema/user"
require "command_tower/schema/page"

module CommandTower
  module Schema
    module Admin
      class Users < JsonSchematize::Generator
        add_field name: :users, array_of_types: true, type: CommandTower::Schema::User
        add_field name: :count, type: Integer, required: false
        add_field name: :pagination, type: CommandTower::Schema::Page, required: false
      end
    end
  end
end
