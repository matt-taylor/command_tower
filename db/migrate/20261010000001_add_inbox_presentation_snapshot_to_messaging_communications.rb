# frozen_string_literal: true

class AddInboxPresentationSnapshotToMessagingCommunications < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_communications, :inbox_presentation_snapshot, :json
  end
end
