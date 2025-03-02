# frozen_string_literal: true

require "api_engine_base/schema/inbox/message_entity"
require "api_engine_base/schema/page"

module ApiEngineBase
  module Schema
    module Inbox
      class Metadata < JsonSchematize::Generator
        # schema_default option: :dig_type, value: :string

        add_field name: :entities, array_of_types: true, type: ApiEngineBase::Schema::Inbox::MessageEntity, required: false
        add_field name: :count, type: Integer
        add_field name: :pagination, type: ApiEngineBase::Schema::Page, required: false
      end
    end
  end
end
