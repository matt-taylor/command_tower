# frozen_string_literal: true

# Helpers for Accept specs of MessageDefinition-backed types. Expects the including group to
# define `user` and `metadata`.
module MessagingDefinedTypeAcceptHelper
  def build_definition(version:, schema:)
    Class.new(CommandTower::Messaging::MessageDefinition) do
      metadata_version version
      metadata_schema schema
      default_zone "America/Los_Angeles"
      fixture :default, metadata: { "headline" => "Hello" }

      def slots(metadata:, **)
        { headline: metadata["headline"], subject: "Subject", push_body: metadata["push"] }
      end
    end
  end

  def accept(**overrides)
    CommandTower::Messaging::Accept::Coordinator.call(
      **default_accept_attrs(
        user:, notification_type_key: "defined.sample", title: nil, body: nil, metadata:,
        platform_enabled_channels: %w[email], **overrides
      )
    )
  end

  # Accept that is expected to be rejected; returns nil instead of raising.
  def rejected_accept(**overrides)
    accept(**overrides)
  rescue CommandTower::Messaging::Accept::ValidationError
    nil
  end

  def stored(result)
    CommandTower::Messaging::Communication.find(result.communication_id)
  end

  def publisher
    CommandTower::Messaging::Contract::Observability::Publisher
  end

  def validation_error
    CommandTower::Messaging::Accept::ValidationError
  end

  def set_zone(account, zone)
    account.update!(last_known_timezone: zone)
  end
end

RSpec.configure do |config|
  config.include MessagingDefinedTypeAcceptHelper, :defined_type_accept
end
