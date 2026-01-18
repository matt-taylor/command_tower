# frozen_string_literal: true

module CommandTower
  module Schema
    module Auth
      module PlainText
        module EmailVerify
          class SendResponse < JsonSchematize::Generator
            add_field name: :message, type: String
          end
        end
      end
    end
  end
end
