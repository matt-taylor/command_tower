# frozen_string_literal: true

require "openssl"

module CommandTower
  module Services
    module HomeNotices
      # Builds, validates and redacts the document for one notice (design D6, D13).
      #
      # Inputs: `notice_class` (a Campaign or Delivery subclass), `user`, `request_context` (a
      # HomeNotices::Context) and `record` (a NoticeRecord, or nil for an unmaterialized campaign).
      #
      # Success data is `{ document:, content_hash: }`. `document` is nil, with no hash, when the
      # notice cannot be shown: the client catalog is below 2, or compose or validation failed
      # (the notice is skipped, never raised). A blocking notice is validated with the
      # `:blocking_notice` profile, a dismissible one with the default profile. A blocking failure
      # publishes `command_tower.home_notices.blocking_invalid` (key and error class only).
      #
      # A linked delivery (`composer :message`) takes its document from
      # `Messaging::Contract::Inbox.document_for_communication` instead of `compose`.
      #
      # The hash is an HMAC-SHA256 of the composed, redacted document JSON (D13). Rotating
      # `secret_key_base` makes stored hashes unverifiable.
      class Compose < CommandTower::Services::ApplicationService
        MIN_CATALOG = 2
        HASH_KEY_SALT = "command_tower/home_notices/content_hash"
        HASH_KEY_BYTES = 32

        validate :notice_class, is_a: Class, required: true
        validate :user, is_a: User, required: true
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true
        validate :record, is_a: CommandTower::HomeNotices::NoticeRecord, required: false

        def call
          document = build_document
          context.document = document
          context.content_hash = document && content_hash(document)
        end

        private

        def build_document
          return nil if request_context.ui_catalog.to_i < MIN_CATALOG

          composed = linked? ? linked_document : compose_valid_document
          return nil if composed.nil?

          CommandTower::UI::Redaction.call(composed, impersonating: request_context.impersonating)
        rescue StandardError => e
          log_failure(e)
          nil
        end

        def linked?
          notice_class < CommandTower::HomeNotices::Delivery && notice_class.composer == :message
        end

        # A linked delivery shows the inbox item's own document, fetched through the Messaging
        # contract (never the host `compose`). Nil when the item is missing, deleted, archived,
        # foreign or undefined: the notice is then not shown.
        def linked_document
          return nil if record&.communication_id.nil?

          request = CommandTower::Messaging::Contract::Requests::DocumentForCommunication.build(
            communication_id: record.communication_id, recipient_id: user.id,
            impersonating: request_context.impersonating
          )
          result = CommandTower::Messaging::Contract::Inbox.document_for_communication(request)
          result&.document&.validate!(profile:)
        end

        def compose_valid_document
          root = built_document.validate!(profile:).root
          fallback = CommandTower::UI::TextDerivation.call(root, **derivation_options)
          CommandTower::UI::Document.new(root:, text_fallback: fallback).validate!(profile:)
        end

        def built_document
          CommandTower::UI.document(text_fallback: "-") do |builder|
            notice_class.new.compose(builder, user:, context: request_context, notice: record)
          end
        end

        def profile
          notice_class.blocking? ? :blocking_notice : :default
        end

        def derivation_options
          zone = request_context.time_zone
          zone.present? ? { user_zone: zone } : {}
        end

        def content_hash(document)
          OpenSSL::HMAC.hexdigest("SHA256", hash_key, document.as_json.to_json)
        end

        def hash_key
          Rails.application.key_generator.generate_key(HASH_KEY_SALT, HASH_KEY_BYTES)
        end

        # Keys and error classes only: never document content, spans or hrefs.
        def log_failure(error)
          name = notice_class.blocking? ? "blocking_invalid" : "compose_failed"
          CommandTower::Events.publish(
            category: :home_notices,
            name:,
            payload: { notice_key: notice_class.key.to_s, error_class: error.class.name, log_level: :warn }
          )
        end
      end
    end
  end
end
