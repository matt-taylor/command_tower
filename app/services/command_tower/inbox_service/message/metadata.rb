# frozen_string_literal: true

module CommandTower
  module InboxService
    module Message
      class Metadata < CommandTower::ServiceBase
        include CommandTower::PaginationServiceHelper

        on_argument_validation :fail_early

        validate :user, is_a: User, required: true

        def call
          entities = query.map do |message|
            CommandTower::Schema::Inbox::MessageEntity.new(
              id: message.id,
              title: message.title,
              viewed: message.viewed,
            )
          end

          params = {
            count: entities.length,
            entities: entities.nil? ? nil : entities,
            pagination: pagination_schema,
          }.compact
          context.metadata = CommandTower::Schema::Inbox::Metadata.new(**params)
        end

        def default_query
          ::Message.where(user:).select(:id, :title, :viewed)
        end
      end
    end
  end
end





