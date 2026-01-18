# frozen_string_literal: true

require "command_tower/schema/shared/admin/users"

module CommandTower
  module Schema
    module Admin
      module Show
        class Response < JsonSchematize::Generator
          # Response is the Shared::Admin::Users schema
          # We'll use it directly in the controller
        end
      end
    end
  end
end
