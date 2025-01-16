# frozen_string_literal: true

require "api_engine_base/schema/user"
require "api_engine_base/schema/page"

module ApiEngineBase
  module Schema
    module Admin
      class Users < JsonSchematize::Generator
        add_field name: :users, array_of_types: true, type: ApiEngineBase::Schema::User
        add_field name: :pagination, type: ApiEngineBase::Schema::Page, required: false
      end
    end
  end
end
