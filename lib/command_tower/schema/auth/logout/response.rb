# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module Logout
        class Response < JsonSchematize::Generator
          add_field name: :message, type: String
        end
      end
    end
  end
end
