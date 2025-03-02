# frozen_string_literal: true

module CommandTower
  module Schema
    module PlainText
      class EmailVerifyResponse< JsonSchematize::Generator
        add_field name: :message, type: String
      end
    end
  end
end
