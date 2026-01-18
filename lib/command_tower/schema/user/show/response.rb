# frozen_string_literal: true

require "command_tower/schema/shared/user"

module CommandTower
  module Schema
    module User
      module Show
        class Response < JsonSchematize::Generator
          # Response is just the User schema
          # We'll use Shared::User directly in the controller
        end
      end
    end
  end
end
