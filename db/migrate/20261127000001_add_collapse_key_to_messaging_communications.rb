# frozen_string_literal: true

class AddCollapseKeyToMessagingCommunications < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_communications, :collapse_key, :string, limit: 64, null: true
  end
end
