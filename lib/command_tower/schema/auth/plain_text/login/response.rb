# frozen_string_literal: true

require "command_tower/schema/shared/user"

module CommandTower
  module Schema
    module Auth
      module PlainText
        module Login
          class Response < JsonSchematize::Generator
            add_field name: :token, type: String
            add_field name: :header_name, type: String
            add_field name: :message, type: String
            add_field name: :user, type: CommandTower::Schema::Shared::User
          end
        end
      end
    end
  end
end
