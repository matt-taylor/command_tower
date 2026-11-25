# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Gathers the unfiltered selection candidates for one user (design §3.4 step 1, doc 03 §7).
      # `Select` applies the drop rules.
      #
      # Inputs: `user` and `request_context` (a HomeNotices::Context; `now` is the clock).
      #
      # Success data is `{ pairs: [[notice_class, row], ...] }`:
      # - the user's open deliveries (unacknowledged, not ended at `now`), oldest first, at most
      #   `config.home_notices.max_open_deliveries`, kept only when their key is a registered Delivery
      # - every registered campaign, with its row for the current period, or nil when it has none.
      #   A campaign whose `period_key` block raises is skipped and
      #   `command_tower.home_notices.period_key_failed` is published (key and error class only).
      class LoadCandidates < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          context.pairs = delivery_pairs + campaign_pairs
        end

        private

        def now
          request_context.now
        end

        def delivery_pairs
          open_delivery_rows.filter_map do |row|
            klass = CommandTower::HomeNotices::Catalog.find(row.key)
            [klass, row] if klass && klass < CommandTower::HomeNotices::Delivery
          end
        end

        def open_delivery_rows
          CommandTower::HomeNotice
            .where(user_id: user.id, kind: "delivery", acknowledged_at: nil)
            .where("ends_at IS NULL OR ends_at > ?", now)
            .order(:created_at, :id)
            .limit(CommandTower.config.home_notices.max_open_deliveries)
            .to_a
        end

        def campaign_pairs
          period_keys = campaign_classes.each_with_object({}) do |klass, memo|
            period_key = period_key_for(klass)
            memo[klass] = period_key unless period_key.nil?
          end
          rows = campaign_rows(period_keys)

          period_keys.map { |klass, period_key| [klass, rows[[klass.key, period_key]]] }
        end

        def campaign_classes
          CommandTower::HomeNotices::Catalog.notices.select { |klass| klass < CommandTower::HomeNotices::Campaign }
        end

        # The stored period key, "" without a `period_key` block, or nil when the block raises.
        def period_key_for(klass)
          block = klass.period_key
          raw = block ? block.call(user:, context: request_context) : ""
          CommandTower::HomeNotice.stored_period_key(raw)
        rescue StandardError => e
          CommandTower::Events.publish(
            category: :home_notices,
            name: "period_key_failed",
            payload: { notice_key: klass.key.to_s, error_class: e.class.name, log_level: :warn }
          )
          nil
        end

        def campaign_rows(period_keys)
          return {} if period_keys.empty?

          CommandTower::HomeNotice
            .where(user_id: user.id, campaign_key: period_keys.keys.map(&:key), period_key: period_keys.values.uniq)
            .index_by { |row| [row.campaign_key, row.period_key] }
        end
      end
    end
  end
end
