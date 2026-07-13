# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module ChangePassword
          class Response < JsonSchematize::Generator
            add_field name: :message, type: String
          end
        end
      end
    end
  end
end
