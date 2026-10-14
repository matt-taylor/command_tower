# frozen_string_literal: true

class AddProviderMetadataToMessagingDeliveryAttempts < ActiveRecord::Migration[7.2]
  def change
    add_column :messaging_delivery_attempts, :provider_metadata, :json
  end
end
