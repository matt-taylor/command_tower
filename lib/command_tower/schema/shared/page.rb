# frozen_string_literal: true

module CommandTower
  module Schema
    module Shared
      class Page < JsonSchematize::Generator
        add_field name: :cursor, type: Integer
        add_field name: :limit, type: Integer
        add_field name: :query, type: String
      end
    end
  end
end
