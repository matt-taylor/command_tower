# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Blast
      class Metadata  < ApiEngineBase::ServiceBase
        def call
          entities = ::MessageBlast.all.select(:id, :title, :existing_users, :new_users).map do |mb|
            ApiEngineBase::Schema::Inbox::MessageBlastEntity.new(
              title: mb.title,
              id: mb.id,
              existing_users: mb.existing_users,
              new_users: mb.new_users,
            )
          end


          context.metadata = ApiEngineBase::Schema::Inbox::MessageBlastMetadata.new(
            entities: entities,
            count: entities.length,
          )
        end
      end
    end
  end
end
