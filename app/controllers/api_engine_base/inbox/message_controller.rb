# frozen_string_literal: true

module ApiEngineBase
  module Inbox
    class MessageController < ::ApiEngineBase::ApplicationController
      include ApiEngineBase::SchemaHelper

      before_action :authenticate_user!

      # GET: /inbox/messages
      def metadata
        result = ApiEngineBase::InboxService::Message::Metadata.(user: current_user)
        if result.success?
          schema = result.metadata
          status = 200
          schema_succesful!(status:, schema:)
        else
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: ApiEngineBase::Schema::PlainText::LoginRequest
          )
        end
      end

      # GET: /inbox/messages/:id
      def message
        result = ApiEngineBase::InboxService::Message::Retrieve.(user: current_user, id: params[:id].to_i)
        if result.success?
          schema = result.message
          status = 200
          schema_succesful!(status:, schema:)
        else
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: ApiEngineBase::Schema::PlainText::LoginRequest
          )
        end
      end

      # POST: /inbox/messages/ack
      # Body { ids: [<list of ids to ack>] }
      def ack
        modify(type: ApiEngineBase::InboxService::Message::Modify::VIEWED)
      end

      # POST: /inbox/messages/delete
      # Body { ids: [<list of ids to delete>] }
      def delete
        modify(type: ApiEngineBase::InboxService::Message::Modify::DELETE)
      end

      private

      def modify(type:)
        result = ApiEngineBase::InboxService::Message::Modify.(
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
            schema: ApiEngineBase::Schema::PlainText::LoginRequest
          )
        end
      end
    end
  end
end
