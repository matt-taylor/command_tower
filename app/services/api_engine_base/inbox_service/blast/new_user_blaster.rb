# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Blast
      class NewUserBlaster  < ApiEngineBase::ServiceBase
        on_argument_validation :fail_early

        validate :user, is_a: User, required: true

        def call
          ::MessageBlast.where(new_users: true).each do |message_blast|
            InboxService::Message::Send.(
              user:,
              text: message_blast.text,
              title: message_blast.title,
              message_blast:,
            )
          end
        end
      end
    end
  end
end
