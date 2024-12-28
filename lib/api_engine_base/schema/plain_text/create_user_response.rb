# frozen_string_literal: true

module ApiEngineBase
  module Schema
    module PlainText
      class CreateUserResponse < JsonSchematize::Generator
        add_field name: :full_name, type: String
        add_field name: :first_name, type: String
        add_field name: :last_name, type: String
        add_field name: :username, type: String
        add_field name: :email, type: String
        add_field name: :msg, type: String
      end
    end
  end
end

