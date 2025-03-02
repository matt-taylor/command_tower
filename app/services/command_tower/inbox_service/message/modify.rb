# frozen_string_literal: true

module CommandTower
  module InboxService
    module Message
      class Modify < CommandTower::ServiceBase
        on_argument_validation :fail_early

        IS_ONE = [
          VIEWED = :viewed,
          DELETE = :delete,
        ]
        validate :user, is_a: User, required: true
        validate :ids, is_a: Array, required: true
        validate :type, is_one: IS_ONE, required: true

        def call
          messages = ::Message.where(user:, id: ids)
          if messages.empty?
            inline_argument_failure!(errors: { ids: "No ID's found for user" })
          end

          case type
          when VIEWED
            modified_ids = messages.update(viewed: true).pluck(:id)
          when DELETE
            modified_ids = messages.destroy_all.pluck(:id)
          end

          context.modified = CommandTower::Schema::Inbox::Modified.new(
            ids: modified_ids,
            type:,
            count: modified_ids.length,
          )
        end
      end
    end
  end
end





