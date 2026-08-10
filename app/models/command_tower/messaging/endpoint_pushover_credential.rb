# frozen_string_literal: true

module CommandTower
  module Messaging
    class EndpointPushoverCredential < CommandTower::ApplicationRecord
      self.table_name = "messaging_endpoint_pushover_credentials"

      belongs_to :endpoint,
                 class_name: "CommandTower::Messaging::Endpoint",
                 foreign_key: :messaging_endpoint_id,
                 inverse_of: :pushover_credential

      validates :user_key_ciphertext, presence: true
      validates :application_token_ciphertext, presence: true
      validates :encryption_key_version, presence: true
    end
  end
end
