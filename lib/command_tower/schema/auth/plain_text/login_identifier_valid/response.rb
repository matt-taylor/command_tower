# frozen_string_literal: true

require "command_tower/schema/shared/user"

module CommandTower
  module Schema
    module Auth
      module PlainText
        module LoginIdentifierValid
          class Response < JsonSchematize::Generator
            add_field name: :valid, type: JsonSchematize::Boolean
            add_field name: :message, type: String
            add_field name: :user, type: CommandTower::Schema::Shared::User
          end
        end
      end
    end
  end
end
