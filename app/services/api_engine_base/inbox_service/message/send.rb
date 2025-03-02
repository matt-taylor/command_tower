# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Message
      class Send  < ApiEngineBase::ServiceBase
        validate :user, is_a: User, required: true
        validate :text, is_a: String, required: true
        validate :title, is_a: String, required: true
        validate :message_blast, is_a: ::MessageBlast, required: false
        validate :pushed, is_one: [true, false], default: false

        def call
          message = create_message!
          context.message = message
        end

        def push_notification!
          # TODO: Push notifications
        end

        def create_message!
          ::Message.create!(
            user:,
            text: ,
            title: ,
            message_blast:,
          )
        end
      end
    end
  end
end
