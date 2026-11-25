# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Re-checks a resolved notice before a mutation (design §3.4 "Mutation re-checks"). It never
      # runs `show?`: a user who saw a notice can always clear it.
      #
      # Inputs: `notice_class` and `row` (from `ResolveNotice`; the row is nil for a campaign with no
      # row yet) and `request_context` (a HomeNotices::Context; `now` is the clock). Ownership is
      # settled by `ResolveNotice`, which only finds the user's own rows.
      #
      # Checks, in order:
      # - registration: the class is registered, and its kind matches the row (a delivery needs a row)
      # - kill switch: an absent control row means enabled
      # - window: the class `window` and the row's own `starts_at` / `ends_at`
      #   (`starts_at` inclusive, `ends_at` exclusive)
      # - pacing state, only with `for_impression: true`: not acknowledged and not dismissed into the
      #   future. Period max and item cooldown are not re-checked: `Select` applied them when it
      #   served the notice, and a repeat impression inside the cooldown is an idempotent
      #   `recorded: false`, not a 404.
      #
      # Success data is `{}`. An ineligible notice fails with `NotFoundError`. When the controls
      # cannot be read the result fails with the `InternalError` from `ReadControls` (the caller maps
      # it to 503 `home_notices_unavailable`).
      class CheckMutationEligibility < CommandTower::Services::ApplicationService
        validate :notice_class, is_a: [Class, NilClass], required: false
        validate :row, is_a: [CommandTower::HomeNotice, NilClass], required: false
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true
        validate :for_impression, is_one: [true, false], default: false

        def call
          return not_found unless registered?

          check_controls
          not_found unless inside_window? && (!for_impression || open_state?)
        end

        private

        def now
          request_context.now
        end

        def registered?
          return false if notice_class.nil? || !CommandTower::HomeNotices::Catalog.registered?(notice_class.key)

          notice_class < CommandTower::HomeNotices::Delivery ? !row.nil? : campaign_row_matches?
        end

        def campaign_row_matches?
          row.nil? || row.campaign_key == notice_class.key
        end

        def check_controls
          result = ReadControls.call(keys: [notice_class.key])
          return not_found if result.success? && result.data[:disabled_keys].include?(notice_class.key)
          return if result.success?

          context.fail!(application_error: result.errors.first)
        end

        def inside_window?
          window = notice_class.window
          return false unless window.nil? || inside?(window.starts_at, window.ends_at)

          row.nil? || inside?(row.starts_at, row.ends_at)
        end

        def inside?(starts_at, ends_at)
          (starts_at.nil? || starts_at <= now) && (ends_at.nil? || ends_at > now)
        end

        def open_state?
          row.nil? || (row.acknowledged_at.nil? && (row.dismissed_until.nil? || row.dismissed_until <= now))
        end

        def not_found
          context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
        end
      end
    end
  end
end
