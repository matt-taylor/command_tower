# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Pushes one Delivery notice to one user (design D9). Host workflows call it directly after
      # `Produce`.
      #
      # Inputs: `user`, `notice` (a Delivery subclass), `identity` (the caller's stable key for this
      # occurrence), `communication_id` (required for a linked delivery), `starts_at`, `ends_at` and
      # `metadata` (a Hash, ids and small values only).
      #
      # - Idempotent on `(user, identity)`: a repeat returns the existing row and writes nothing.
      # - A linked delivery (`composer :message`) is refused with `LinkedMessageUnavailableError`
      #   (`linked_message_unavailable`) when the inbox item is missing, deleted, foreign or
      #   undefined. No row is written.
      # - Over `max_open_deliveries` open rows the delivery is ignored and
      #   `command_tower.home_notices.delivery_over_cap` is published (key only).
      #
      # Success data is `{ delivered:, public_id: }`. `delivered` is true only when this call wrote
      # the row; `public_id` is nil when the delivery was ignored over the cap.
      class Deliver < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :notice, is_a: Class, required: true
        validate :identity, is_a: String, required: true
        validate :communication_id, is_a: [Integer, NilClass], required: false
        validate :starts_at, is_a: [Time, ActiveSupport::TimeWithZone, NilClass], required: false
        validate :ends_at, is_a: [Time, ActiveSupport::TimeWithZone, NilClass], required: false
        validate :metadata, is_a: [Hash, NilClass], required: false

        def call
          return invalid unless delivery_class?

          existing = existing_row
          return finish(delivered: false, public_id: existing.public_id) if existing
          return unavailable if linked? && !linked_message_available?
          return over_cap if open_count >= CommandTower.config.home_notices.max_open_deliveries

          create_row
        end

        private

        def delivery_class?
          notice < CommandTower::HomeNotices::Delivery
        end

        def linked?
          notice.composer == :message
        end

        def scope
          CommandTower::HomeNotice.where(user_id: user.id)
        end

        def existing_row
          scope.find_by(identity:)
        end

        def open_count
          scope.where(kind: "delivery", acknowledged_at: nil)
               .where("ends_at IS NULL OR ends_at > ?", Time.current)
               .count
        end

        def linked_message_available?
          return false if communication_id.nil?

          request = CommandTower::Messaging::Contract::Requests::DocumentForCommunication.build(
            communication_id:, recipient_id: user.id, impersonating: false
          )
          !CommandTower::Messaging::Contract::Inbox.document_for_communication(request).nil?
        end

        def create_row
          row = CommandTower::HomeNotice.create!(
            user:, kind: "delivery", key: notice.key, identity:, communication_id:,
            starts_at:, ends_at:, metadata: metadata || {}
          )
          finish(delivered: true, public_id: row.public_id)
        rescue ActiveRecord::RecordNotUnique
          finish(delivered: false, public_id: existing_row&.public_id)
        end

        def over_cap
          CommandTower::Events.publish(
            category: :home_notices,
            name: "delivery_over_cap",
            payload: { notice_key: notice.key.to_s, log_level: :warn }
          )
          finish(delivered: false, public_id: nil)
        end

        def finish(delivered:, public_id:)
          context.delivered = delivered
          context.public_id = public_id
        end

        def invalid
          context.fail!(application_error: CommandTower::Errors::ValidationError.new(
            details: { notice: ["must be a Delivery subclass"] }
          ))
        end

        def unavailable
          context.fail!(application_error: CommandTower::Errors::HomeNotices::LinkedMessageUnavailableError.new)
        end
      end
    end
  end
end
