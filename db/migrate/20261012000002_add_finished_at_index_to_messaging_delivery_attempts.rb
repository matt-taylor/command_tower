# frozen_string_literal: true

class AddFinishedAtIndexToMessagingDeliveryAttempts < ActiveRecord::Migration[7.2]
  def change
    add_index :messaging_delivery_attempts, :finished_at,
              name: "index_messaging_delivery_attempts_on_finished_at"
  end
end
