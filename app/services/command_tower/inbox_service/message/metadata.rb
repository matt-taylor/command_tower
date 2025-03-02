# frozen_string_literal: true

module CommandTower
  module InboxService
    module Message
      class Metadata < CommandTower::ServiceBase
        on_argument_validation :fail_early

        validate :user, is_a: User, required: true

        def call
          entities = ::Message.where(user:).select(:id, :title, :viewed).map do |message|
            CommandTower::Schema::Inbox::MessageEntity.new(
              title:  message.title,
              id:  message.id,
              viewed:  message.viewed,
            )
          end

          params = {
            entities: entities.nil? ? nil : entities,
            count: entities.length,
          }

          context.metadata = CommandTower::Schema::Inbox::Metadata.new(**params.compact)
        end
      end
    end
  end
end





