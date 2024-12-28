# frozen_string_literal: true

module ApiEngineBase
  module Schema
    module PlainText
      class LoginResponse < JsonSchematize::Generator
        add_field name: :token, type: String
        add_field name: :header_name, type: String
        add_field name: :message, type: String
      end
    end
  end
end
