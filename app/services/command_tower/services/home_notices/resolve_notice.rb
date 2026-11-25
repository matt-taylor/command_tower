# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Finds the notice a mutation (impression, acknowledge, dismiss) names, for one user only
      # (design §3.3 "Ids", §3.4).
      #
      # Inputs: `user`, `notice_id` (a `Deserializers::HomeNotices::NoticeIdDeserializer::Input`) and
      # `request_context` (a HomeNotices::Context; `now` and the user feed a campaign `period_key`).
      #
      # - `public_id`: the user's own row. Another user's row is indistinguishable from a missing one.
      # - `campaign:<key>`: the registered campaign and the user's row for its current period, or a nil
      #   row when the period has none yet. An unregistered key, or a `period_key` block that raises,
      #   is not found.
      #
      # Success data is `{ notice_class:, row:, period_key: }`. `notice_class` is nil only for a
      # `public_id` row whose key is no longer registered; `CheckMutationEligibility` rejects that.
      # Anything not found fails with `NotFoundError`. Eligibility is not checked here.
      class ResolveNotice < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :notice_id, is_a: CommandTower::Deserializers::HomeNotices::NoticeIdDeserializer::Input, required: true
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          notice_id.public_id ? resolve_row : resolve_campaign
        end

        private

        def resolve_row
          row = CommandTower::HomeNotice.find_by(user_id: user.id, public_id: notice_id.public_id)
          return not_found if row.nil?

          succeed(CommandTower::HomeNotices::Catalog.find(row.key), row, row.period_key)
        end

        def resolve_campaign
          klass = CommandTower::HomeNotices::Catalog.campaign(notice_id.campaign_key)
          return not_found if klass.nil?

          period_key = current_period_key(klass)
          return not_found if period_key.nil?

          row = CommandTower::HomeNotice.find_by(user_id: user.id, campaign_key: klass.key, period_key:)
          succeed(klass, row, period_key)
        end

        # The stored period key, "" without a `period_key` block, or nil when the block raises.
        def current_period_key(klass)
          block = klass.period_key
          CommandTower::HomeNotice.stored_period_key(block ? block.call(user:, context: request_context) : "")
        rescue StandardError
          nil
        end

        def succeed(notice_class, row, period_key)
          context.notice_class = notice_class
          context.row = row
          context.period_key = period_key
        end

        def not_found
          context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
        end
      end
    end
  end
end
