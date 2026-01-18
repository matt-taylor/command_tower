# frozen_string_literal: true

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Delete
          class Response < JsonSchematize::Generator
            add_field name: :id, type: Integer
            add_field name: :msg, type: String
          end
        end
      end
    end
  end
end
