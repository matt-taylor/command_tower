# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Blast
      class Retrieve < ApiEngineBase::ServiceBase
        on_argument_validation :fail_early

        validate :id, is_a: Integer, required: true

        def call
          message_blast = ::MessageBlast.where(id:).first

          if message_blast.nil?
            inline_argument_failure!(errors: { id: "MessageBlast ID not found" })
          end

          context.message_blast = ApiEngineBase::Schema::Inbox::MessageBlastEntity.new(
            created_by: ApiEngineBase::Schema::User.convert_user_object(user: message_blast.user),
            title: message_blast.title,
            text: message_blast.text,
            id: message_blast.id,
            existing_users: message_blast.existing_users,
            new_users: message_blast.new_users,
          )
        end
      end
    end
  end
end
