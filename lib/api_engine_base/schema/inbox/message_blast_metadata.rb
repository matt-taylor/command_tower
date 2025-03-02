# frozen_string_literal: true

require "api_engine_base/schema/inbox/message_blast_entity"
require "api_engine_base/schema/page"

module ApiEngineBase
  module Schema
    module Inbox
      class MessageBlastMetadata < JsonSchematize::Generator
        add_field name: :entities, array_of_types: true, type: ApiEngineBase::Schema::Inbox::MessageBlastEntity, required: false
        add_field name: :count, type: Integer
        add_field name: :pagination, type: ApiEngineBase::Schema::Page, required: false
      end
    end
  end
end
