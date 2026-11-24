# frozen_string_literal: true

class AddMessageDefinitionColumnsToMessagingCommunications < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_communications, :slots, :json
    add_column :messaging_communications, :render_zone, :string, limit: 64
    add_column :messaging_communications, :metadata_version, :integer
  end
end
