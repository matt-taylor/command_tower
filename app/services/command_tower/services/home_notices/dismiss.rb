# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Dismisses one resolved dismissible notice for its user (design D3, §3.4).
      #
      # Inputs: `user`, `notice_class`, `row` and `period_key` (from `ResolveNotice`; the row is nil
      # for a campaign with no row in the current period yet) and `request_context` (a
      # HomeNotices::Context; `now` is the clock). Eligibility is the caller's job
      # (`CheckMutationEligibility`). It never runs `show?`: a user who saw a notice can always clear
      # it.
      #
      # Only a dismissible notice can be dismissed. A blocking notice fails with `ValidationError`
      # and nothing is written. Nothing is written while impersonating or when impersonation is
      # unknown (`impersonating` is not `false`): the result fails with `ForbiddenError`.
      #
      # `dismissed_until` is `now + DISMISSAL_DURATION`. The decision to audit comes from an atomic
      # write, never from a read before it, so concurrent requests dismiss and audit exactly once.
      # The write and the audit share one transaction:
      # - existing row: `dismissed_until` is set only
      #   `WHERE dismissed_until IS NULL OR dismissed_until <= now`. Exactly one row changed means
      #   this request dismissed it and `home_notice_dismissed` is audited. No row changed means it is
      #   already dismissed into the future: an idempotent success with no audit.
      # - campaign with no row: `insert!` creates the row already dismissed. On `RecordNotUnique` a
      #   concurrent request created it first, and this one continues as the existing-row case.
      #
      # Success data is `{ dismissed: true, recorded:, public_id:, dismissed_until: }`. `recorded` is
      # true only when this request made the change (and audited it).
      class Dismiss < CommandTower::Services::ApplicationService
        # How long a dismissed notice stays hidden. The notice's window, kill switch and pacing
        # still apply after it lapses.
        DISMISSAL_DURATION = 7.days

        validate :user, is_a: User, required: true
        validate :notice_class, is_a: Class, required: true
        validate :row, is_a: [CommandTower::HomeNotice, NilClass], required: false
        validate :period_key, is_a: [String, NilClass], required: false
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          return forbidden unless request_context.impersonating == false
          return not_found if row.nil? && !campaign?
          return not_dismissible unless notice_class.dismissible?

          transaction { dismiss }
        end

        private

        def now
          request_context.now
        end

        def dismissed_until
          now + DISMISSAL_DURATION
        end

        def campaign?
          notice_class < CommandTower::HomeNotices::Campaign
        end

        def stored_period_key
          CommandTower::HomeNotice.stored_period_key(period_key)
        end

        def dismiss
          return dismiss_existing(row.id, row.public_id) if row

          public_id = insert_campaign_row
          return dismissed!(public_id) if public_id

          id, existing_public_id = campaign_scope.lock.pick(:id, :public_id)
          dismiss_existing(id, existing_public_id)
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
            campaign_key: notice_class.key, period_key: stored_period_key, dismissed_until:
          }
        end

        def dismiss_existing(id, public_id)
          changed = CommandTower::HomeNotice
                    .where(id:)
                    .where("dismissed_until IS NULL OR dismissed_until <= ?", now)
                    .update_all(dismissed_until:, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
          return dismissed!(public_id) if changed == 1

          finish(recorded: false, public_id:, until_time: CommandTower::HomeNotice.where(id:).pick(:dismissed_until))
        end

        def dismissed!(public_id)
          audit(:home_notice_dismissed, affected_user: user, changes: {}, metadata: audit_metadata(public_id))
          finish(recorded: true, public_id:, until_time: dismissed_until)
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

        def finish(recorded:, public_id:, until_time:)
          context.dismissed = true
          context.recorded = recorded
          context.public_id = public_id
          context.dismissed_until = until_time
        end

        def forbidden
          context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
        end

        def not_found
          context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
        end

        def not_dismissible
          context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { notice: "blocking" }))
        end
      end
    end
  end
end
