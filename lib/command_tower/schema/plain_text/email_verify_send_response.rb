# frozen_string_literal: true

module CommandTower
  module Schema
    module PlainText
      class EmailVerifySendResponse< JsonSchematize::Generator
        add_field name: :message, type: String
      end
    end
  end
end
