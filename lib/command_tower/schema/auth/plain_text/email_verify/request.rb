# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module EmailVerify
          class Request < JsonSchematize::Generator
            add_field name: :code, type: String
          end
        end
      end
    end
  end
end
