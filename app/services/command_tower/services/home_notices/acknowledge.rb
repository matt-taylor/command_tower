# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Acknowledges one resolved notice for its user (design D3, D13, §3.4).
      #
      # Inputs: `user`, `notice_class`, `row` and `period_key` (from `ResolveNotice`; the row is nil
      # for a campaign with no row in the current period yet) and `request_context` (a
      # HomeNotices::Context; `now` is the clock). Eligibility is the caller's job
      # (`CheckMutationEligibility`). It never runs `show?`: a user who saw a notice can always clear
      # it, even when `show?` is now false or raises.
      #
      # The decision to audit comes from an atomic write, never from a read before it, so concurrent
      # requests acknowledge and audit exactly once. The write and the audit share one transaction:
      # - existing row: `acknowledged_at` is set only `WHERE acknowledged_at IS NULL`. Exactly one row
      #   changed means this request acknowledged it and `home_notice_acknowledged` is audited. No row
      #   changed means it was already acknowledged: an idempotent success with no audit.
      # - campaign with no row: `insert!` creates the row already acknowledged. On `RecordNotUnique`
      #   a concurrent request created it first, and this one continues as the existing-row case.
      #
      # A blocking notice also stores the content hash of the document it showed (HMAC from
      # `Compose`) in `acknowledged_content_hash`. The hash is composed before the transaction opens
      # (compose runs host code) and is nil when the document cannot be composed. It is never put
      # in audit metadata (design D4).
      #
      # Nothing is written while impersonating or when impersonation is unknown (`impersonating` is
      # not `false`): the result fails with `ForbiddenError`.
      #
      # Success data is `{ acknowledged: true, recorded:, public_id: }`. `recorded` is true only when
      # this request made the change (and audited it).
      class Acknowledge < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :notice_class, is_a: Class, required: true
        validate :row, is_a: [CommandTower::HomeNotice, NilClass], required: false
        validate :period_key, is_a: [String, NilClass], required: false
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          return forbidden unless request_context.impersonating == false
          return not_found if row.nil? && !campaign?

          hash = content_hash
          transaction { acknowledge(hash) }
        end

        private

        def now
          request_context.now
        end

        def campaign?
          notice_class < CommandTower::HomeNotices::Campaign
        end

        def stored_period_key
          CommandTower::HomeNotice.stored_period_key(period_key)
        end

        # Only a blocking acknowledgement keeps a hash.
        def content_hash
          return nil unless notice_class.blocking?

          snapshot = row && CommandTower::HomeNotices::NoticeRecord.from(row)
          CommandTower::Services::HomeNotices::Compose.call(
            notice_class:, user:, request_context:, record: snapshot
          ).data[:content_hash]
        end

        def acknowledge(hash)
          return acknowledge_existing(row.id, row.public_id, hash) if row

          public_id = insert_campaign_row(hash)
          return acknowledged!(public_id) if public_id

          id, existing_public_id = campaign_scope.lock.pick(:id, :public_id)
          acknowledge_existing(id, existing_public_id, hash)
        end

        def campaign_scope
          CommandTower::HomeNotice.where(
            user_id: user.id, campaign_key: notice_class.key, period_key: stored_period_key
          )
        end

        # The new row's public id, or nil when the row already exists.
        def insert_campaign_row(hash)
          attributes = new_campaign_attributes(hash)
          CommandTower::HomeNotice.transaction(requires_new: true) do
            CommandTower::HomeNotice.insert!(attributes) # rubocop:disable Rails/SkipsModelValidations
          end
          attributes[:public_id]
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        def new_campaign_attributes(hash)
          {
            public_id: SecureRandom.alphanumeric(32), user_id: user.id, kind: "campaign", key: notice_class.key,
            campaign_key: notice_class.key, period_key: stored_period_key,
            acknowledged_at: now, acknowledged_content_hash: hash
          }
        end

        def acknowledge_existing(id, public_id, hash)
          changed = CommandTower::HomeNotice
                    .where(id:, acknowledged_at: nil)
                    .update_all(acknowledged_at: now, acknowledged_content_hash: hash, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
          return acknowledged!(public_id) if changed == 1

          finish(recorded: false, public_id:)
        end

        def acknowledged!(public_id)
          audit(
            :home_notice_acknowledged,
            subject: user, affected_user: user, changes: {}, metadata: audit_metadata(public_id)
          )
          finish(recorded: true, public_id:)
        end

        # Ids only (design §3.5): never the content hash.
        def audit_metadata(public_id)
          {
            notice_id: public_id,
            key: notice_class.key,
            kind: campaign? ? "campaign" : "delivery",
            severity: notice_class.severity.to_s
          }
        end

        def finish(recorded:, public_id:)
          context.acknowledged = true
          context.recorded = recorded
          context.public_id = public_id
        end

        def forbidden
          context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
        end

        def not_found
          context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
        end
      end
    end
  end
end
