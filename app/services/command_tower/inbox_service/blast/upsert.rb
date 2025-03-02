# frozen_string_literal: true

module CommandTower
  module InboxService
    module Blast
      class Upsert  < CommandTower::ServiceBase
        on_argument_validation :fail_early

        validate :user, is_a: User, required: true
        validate :existing_users, is_one: [true, false], required: true
        validate :new_users, is_one: [true, false], required: true
        validate :text, is_a: String, required: true
        validate :title, is_a: String, required: true
        validate :id, is_a: Integer, required: false

        def call
          ar = record

          ar.existing_users = existing_users
          ar.new_users = new_users
          ar.text = text
          ar.title = title
          ar.user = user

          # Probably should wrap this in a transaction block
          ar.save!
          blast_messages!(message_blast: ar)

          context.message_blast = ar
          context.blast = CommandTower::Schema::Inbox::BlastResponse.new(
            existing_users:,
            new_users:,
            text:,
            title:,
            id: ar.id,
            created_by: CommandTower::Schema::User.convert_user_object(user:)
          )
        end

        def blast_messages!(message_blast:)
          # Only blast messages to existing users that are brand new
          return if @existing_record
          return unless existing_users

          User.all.each do |u|
            InboxService::Message::Send.(
              user: u,
              text: text,
              title: title,
              message_blast: message_blast,
            )
          end
        end

        def record
          return MessageBlast.new if id.nil?

          record = MessageBlast.where(id:).first
          inline_argument_failure!(errors: { id: "Message Blast ID does not exist" }) if record.nil?

          @existing_record = true
          record
        end
      end
    end
  end
end
