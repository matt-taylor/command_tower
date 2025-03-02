# frozen_string_literal: true

module CommandTower
  module Inbox
    class MessageController < ::CommandTower::ApplicationController
      include CommandTower::SchemaHelper

      before_action :authenticate_user!

      # GET: /inbox/messages
      def metadata
        result = CommandTower::InboxService::Message::Metadata.(user: current_user)
        if result.success?
          schema = result.metadata
          status = 200
          schema_succesful!(status:, schema:)
        else
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: CommandTower::Schema::PlainText::LoginRequest
          )
        end
      end

      # GET: /inbox/messages/:id
      def message
        result = CommandTower::InboxService::Message::Retrieve.(user: current_user, id: params[:id].to_i)
        if result.success?
          schema = result.message
          status = 200
          schema_succesful!(status:, schema:)
        else
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: CommandTower::Schema::PlainText::LoginRequest
          )
        end
      end

      # POST: /inbox/messages/ack
      # Body { ids: [<list of ids to ack>] }
      def ack
        modify(type: CommandTower::InboxService::Message::Modify::VIEWED)
      end

      # POST: /inbox/messages/delete
      # Body { ids: [<list of ids to delete>] }
      def delete
        modify(type: CommandTower::InboxService::Message::Modify::DELETE)
      end

      private

      def modify(type:)
        result = CommandTower::InboxService::Message::Modify.(
          user: current_user,
          ids: params[:ids],
          type:,
        )
        if result.success?
          schema = result.modified
          status = 200
          schema_succesful!(status:, schema:)
        else
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: CommandTower::Schema::PlainText::LoginRequest
          )
        end
      end
    end
  end
end
