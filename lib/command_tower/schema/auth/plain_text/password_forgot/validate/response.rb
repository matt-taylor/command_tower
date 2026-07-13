# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module PasswordForgot
          module Validate
            class Response < JsonSchematize::Generator
              add_field name: :valid, type: JsonSchematize::Boolean
              add_field name: :expires_at, type: String, required: false
            end
          end
        end
      end
    end
  end
end
