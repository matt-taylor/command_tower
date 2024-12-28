# frozen_string_literal: true

module ApiEngineBase
  module Schema
    module PlainText
      class EmailVerifyRequest < JsonSchematize::Generator
        add_field name: :code, type: String
      end
    end
  end
end
