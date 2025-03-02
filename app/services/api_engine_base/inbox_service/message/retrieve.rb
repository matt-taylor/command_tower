# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Message
      class Retrieve < ApiEngineBase::ServiceBase
        on_argument_validation :fail_early

        validate :user, is_a: User, required: true
        validate :id, is_a: Integer, required: true

        def call
          message = ::Message.where(user:, id:).first

          if message.nil?
            inline_argument_failure!(errors: { id: "Message ID not found for user" })
          end

          message.update!(viewed: true)

          context.message = ApiEngineBase::Schema::Inbox::MessageEntity.new(
            title: message.title,
            id: message.id,
            text: message.text,
            viewed: message.viewed,
          )
        end
      end
    end
  end
end





