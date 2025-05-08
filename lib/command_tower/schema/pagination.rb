# frozen_string_literal: true

require "command_tower/schema/page"

module CommandTower
  module Schema
    class Pagination < JsonSchematize::Generator
      add_field name: :current, type: Page
      add_field name: :next, type: Page, required: false
      add_field name: :count_available, type: Integer, required: false
      add_field name: :current_page, type: Integer, required: false
      add_field name: :remaining_pages, type: Integer, required: false
      add_field name: :total_pages, type: Integer, required: false
    end
  end
end
