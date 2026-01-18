# frozen_string_literal: true

module CommandTower
  module Schema
    module Inbox
      module Messages
        module Delete
          class Request < JsonSchematize::Generator
            add_field name: :ids, type: Array, required: true
          end
        end
      end
    end
  end
end
