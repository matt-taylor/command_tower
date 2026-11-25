# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Records one impression of a resolved, eligible notice (design D3, D5, D11).
      #
      # Inputs: `user`, `notice_class`, `row` and `period_key` (from `ResolveNotice`; the row is nil
      # for a campaign with no row in the current period yet) and `request_context` (a
      # HomeNotices::Context; `now` is the clock). Eligibility is the caller's job
      # (`CheckMutationEligibility` with `for_impression: true`).
      #
      # Every decision comes from an atomic write, never from a read before it, so concurrent
      # requests record and audit exactly once. All writes and the audit share one transaction:
      # - first impression of a campaign period: `insert!` creates the row. On `RecordNotUnique` a
      #   concurrent request created it first, and this one continues as a repeat.
      # - repeat impression: `impression_count + 1` and `last_shown_at` only
      #   `WHERE last_shown_at IS NULL OR last_shown_at <= now - 60 s`. No row changed means a
      #   repeat inside the idempotency window: `recorded: false`, no audit.
      # - first impression of an existing row (a delivery, or a campaign row created by another
      #   mutation): `first_shown_at` is set only `WHERE first_shown_at IS NULL`.
      # `home_notice_impression` is audited only when the insert created the row or that
      # `first_shown_at` update changed exactly one row.
      #
      # Rails `upsert` is not used: on mysql2 (`FOUND_ROWS`) an insert and an unchanged duplicate
      # both report one affected row, and the adapter has no `RETURNING`, so the upsert cannot say
      # whether it created the row. The created-signal spec records this; this is the D11 fallback.
      #
      # Nothing is written while impersonating or when impersonation is unknown (`impersonating` is
      # not `false`).
      #
      # Success data is `{ recorded:, first_impression:, public_id: }`. `public_id` is nil only for an
      # unrecorded campaign impression with no row.
      class RecordImpression < CommandTower::Services::ApplicationService
        IDEMPOTENCY_WINDOW = 60.seconds

        validate :user, is_a: User, required: true
        validate :notice_class, is_a: Class, required: true
        validate :row, is_a: [CommandTower::HomeNotice, NilClass], required: false
        validate :period_key, is_a: [String, NilClass], required: false
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          return finish(recorded: false, public_id: row&.public_id) unless writable?
          return not_found if row.nil? && !campaign?

          transaction { record }
        end

        private

        def record
          row ? record_repeat(row.id, row.public_id) : record_campaign
        end

        def now
          request_context.now
        end

        def writable?
          request_context.impersonating == false
        end

        def campaign?
          notice_class < CommandTower::HomeNotices::Campaign
        end

        def stored_period_key
          CommandTower::HomeNotice.stored_period_key(period_key)
        end

        # The first impression of the period creates the row; losing the race to a concurrent
        # request falls through to the repeat path on the row it created.
        def record_campaign
          public_id = insert_campaign_row
          return first_impression!(public_id) if public_id

          id, existing_public_id = campaign_scope.lock.pick(:id, :public_id)
          record_repeat(id, existing_public_id)
        end

        def campaign_scope
          CommandTower::HomeNotice.where(
            user_id: user.id, campaign_key: notice_class.key, period_key: stored_period_key
          )
        end

        # The new row's public id, or nil when the row already exists.
        def insert_campaign_row
          attributes = new_campaign_attributes
          CommandTower::HomeNotice.transaction(requires_new: true) do
            CommandTower::HomeNotice.insert!(attributes) # rubocop:disable Rails/SkipsModelValidations
          end
          attributes[:public_id]
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        def new_campaign_attributes
          {
            public_id: SecureRandom.alphanumeric(32), user_id: user.id, kind: "campaign", key: notice_class.key,
            campaign_key: notice_class.key, period_key: stored_period_key,
            impression_count: 1, first_shown_at: now, last_shown_at: now
          }
        end

        def record_repeat(id, public_id)
          return finish(recorded: false, public_id:) unless count_impression(id) == 1
          return first_impression!(public_id) if mark_first_shown(id) == 1

          finish(recorded: true, public_id:)
        end

        def count_impression(id)
          CommandTower::HomeNotice
            .where(id:)
            .where("last_shown_at IS NULL OR last_shown_at <= ?", now - IDEMPOTENCY_WINDOW)
            .update_all(["impression_count = impression_count + 1, last_shown_at = ?, updated_at = ?", now, now]) # rubocop:disable Rails/SkipsModelValidations
        end

        def mark_first_shown(id)
          CommandTower::HomeNotice
            .where(id:, first_shown_at: nil)
            .update_all(first_shown_at: now, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
        end

        def first_impression!(public_id)
          audit(:home_notice_impression, affected_user: user, changes: {}, metadata: audit_metadata(public_id))
          finish(recorded: true, first_impression: true, public_id:)
        end

        # Ids only (design §3.5).
        def audit_metadata(public_id)
          {
            notice_id: public_id,
            key: notice_class.key,
            kind: campaign? ? "campaign" : "delivery",
            severity: notice_class.severity.to_s
          }
        end

        def finish(recorded:, public_id:, first_impression: false)
          context.recorded = recorded
          context.first_impression = first_impression
          context.public_id = public_id
        end

        def not_found
          context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
        end
      end
    end
  end
end
