# frozen_string_literal: true

class AddResolvedAtToMessagingInboxItems < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_inbox_items, :resolved_at, :datetime, null: true
  end
end
