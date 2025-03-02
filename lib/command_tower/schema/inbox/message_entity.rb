# frozen_string_literal: true

module CommandTower
  module Schema
    module Inbox
      class MessageEntity < JsonSchematize::Generator
        add_field name: :title, type: String
        add_field name: :id, type: Integer
        add_field name: :text, type: String, required: false
        add_field name: :viewed, type: JsonSchematize::Boolean
      end
    end
  end
end
