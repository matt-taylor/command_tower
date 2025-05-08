# frozen_string_literal: true

require "command_tower/schema/user"

module CommandTower
  module Schema
    module PlainText
      class LoginResponse < JsonSchematize::Generator
        add_field name: :token, type: String
        add_field name: :header_name, type: String
        add_field name: :message, type: String
        add_field name: :user, type: CommandTower::Schema::User
      end
    end
  end
end
