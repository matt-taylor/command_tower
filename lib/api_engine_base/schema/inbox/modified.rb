# frozen_string_literal: true

module ApiEngineBase
  module Schema
    module Inbox
      class Modified < JsonSchematize::Generator
        add_field name: :type, type: Symbol
        add_field name: :ids, type: Array
        add_field name: :count, type: Integer
      end
    end
  end
end
