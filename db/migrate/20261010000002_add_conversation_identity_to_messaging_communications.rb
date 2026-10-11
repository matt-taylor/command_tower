# frozen_string_literal: true

class AddConversationIdentityToMessagingCommunications < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_communications, :conversation_key, :string, limit: 128
    add_column :messaging_communications, :conversation_title, :string
    add_index :messaging_communications, %i[user_id conversation_key],
              name: "index_messaging_communications_on_user_and_conversation_key"
  end
end
