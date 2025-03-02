# frozen_string_literal: true

module CommandTower
  module InboxService
    module Blast
      class Metadata  < CommandTower::ServiceBase
        def call
          entities = ::MessageBlast.all.select(:id, :title, :existing_users, :new_users).map do |mb|
            CommandTower::Schema::Inbox::MessageBlastEntity.new(
              title: mb.title,
              id: mb.id,
              existing_users: mb.existing_users,
              new_users: mb.new_users,
            )
          end


          context.metadata = CommandTower::Schema::Inbox::MessageBlastMetadata.new(
            entities: entities,
            count: entities.length,
          )
        end
      end
    end
  end
end
