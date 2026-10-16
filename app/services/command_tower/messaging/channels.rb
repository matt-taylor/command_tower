# frozen_string_literal: true

module CommandTower
  module Messaging
    module Channels
      module_function

      # identity_backed: readiness uses User Identity facts.
      # supports_endpoint_records: Endpoint Platform may persist ledger rows.
      # SMS is Identity-owned only (like email) — not an Endpoint Platform channel.
      DEFINITIONS = [
        Definition.new(
          key: "inbox",
          label: "Inbox",
          description: "In-app messages",
          order: 0,
          glyph_key: "inbox",
          kind: :inbox,
          supports_endpoint_records: false,
          identity_backed: false,
          canonical_provider: nil,
        ),
        Definition.new(
          key: "email",
          label: "Email",
          description: "Email to your account address",
          order: 1,
          glyph_key: "mail",
          kind: :external,
          supports_endpoint_records: false,
          identity_backed: true,
          canonical_provider: "smtp",
        ),
        Definition.new(
          key: "sms",
          label: "SMS",
          description: "Text messages",
          order: 2,
          glyph_key: "message",
          kind: :external,
          supports_endpoint_records: false,
          identity_backed: true,
          canonical_provider: "twilio",
        ),
        Definition.new(
          key: "push",
          label: "Push",
          description: "Alerts on this device",
          order: 3,
          glyph_key: "bell",
          kind: :external,
          supports_endpoint_records: true,
          identity_backed: false,
          canonical_provider: "expo",
        ),
        Definition.new(
          key: "pushover",
          label: "Pushover",
          description: "Pushover alerts",
          order: 4,
          glyph_key: "radio",
          kind: :external,
          supports_endpoint_records: true,
          identity_backed: false,
          canonical_provider: "pushover",
        ),
      ].map(&:freeze).freeze

      INDEX = DEFINITIONS.index_by(&:key).freeze

      def known?(key)
        INDEX.key?(key.to_s)
      end

      def fetch(key)
        INDEX[key.to_s]
      end

      def fetch!(key)
        normalized = key.to_s
        definition = INDEX[normalized]
        raise UnknownChannelError, "unknown channel: #{normalized.inspect}" if definition.nil?

        definition
      end

      def keys
        @keys ||= DEFINITIONS.map(&:key).freeze
      end

      def external_keys
        @external_keys ||= DEFINITIONS.select(&:external?).map(&:key).freeze
      end

      def definitions
        DEFINITIONS
      end
    end
  end
end
