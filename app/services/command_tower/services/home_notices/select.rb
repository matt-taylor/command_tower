# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Chooses the home notices for one user and request (design §3.4, doc 03 §7).
      #
      # Inputs: `user` and `request_context` (a HomeNotices::Context). Every time rule uses
      # `request_context.now`.
      #
      # Candidates come from `LoadCandidates` (open deliveries up to the cap, plus every registered
      # campaign with its current-period row). A candidate is dropped when it is:
      # - killed (an absent control row means enabled)
      # - outside its window: the class `window`, and for a row its `starts_at` / `ends_at`
      #   (`starts_at` inclusive, `ends_at` exclusive)
      # - acknowledged
      # - dismissed into the future (`dismissed_until > now`)
      # - a campaign at its period impression max, or inside its item cooldown
      #   (`last_shown_at + cooldown > now`). Deliveries have no item pacing.
      # The rest are in priority order: highest `priority` first, ties to the oldest row
      # (`created_at`); a campaign with no row counts as newest. `PickNotices` then picks the
      # blocking and dismissible notice (daily cap, global cooldown, `show?`, compose).
      #
      # Success data is `{ candidates:, controls_available:, blocking:, dismissible: }`. Each
      # candidate is a `Candidate(notice_class, record)`, where `record` is a NoticeRecord or nil.
      # `blocking` and `dismissible` are each a `PickNotices::Pick` or nil.
      # `command_tower.home_notices.selected` is published with the user id, the candidate count and
      # the picked keys only. When the controls cannot be read there are no candidates and no picks,
      # `controls_available` is false and `controls_unavailable` is published (user id and error
      # class).
      class Select < CommandTower::Services::ApplicationService
        Candidate = Data.define(:notice_class, :record)

        validate :user, is_a: User, required: true
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true

        def call
          pairs = LoadCandidates.call(user:, request_context:).data[:pairs]
          disabled_keys = read_disabled_keys(pairs)
          candidates = disabled_keys.nil? ? [] : eligible(pairs, disabled_keys)

          context.controls_available = !disabled_keys.nil?
          context.candidates = candidates
          pick_notices(candidates)
        end

        private

        def pick_notices(candidates)
          picks = PickNotices.call(user:, request_context:, candidates:).data
          context.blocking = picks[:blocking]
          context.dismissible = picks[:dismissible]
          publish_selected(candidates.size, picks)
        end

        def now
          request_context.now
        end

        # Set of disabled keys, or nil when the controls cannot be read.
        def read_disabled_keys(pairs)
          result = ReadControls.call(keys: pairs.map { |klass, _row| klass.key })
          return result.data[:disabled_keys] if result.success?

          error = result.errors.first
          publish("controls_unavailable", user_id: user.id, error_class: (error&.cause || error).class.name,
                                          log_level: :error)
          nil
        end

        def eligible(pairs, disabled_keys)
          pairs.each_with_index
               .reject { |(klass, row), _index| dropped?(klass, row, disabled_keys) }
               .sort_by { |(klass, row), index| [-klass.priority, row&.created_at || now, index] }
               .map { |(klass, row), _index| Candidate.new(notice_class: klass, record: snapshot(row)) }
        end

        def snapshot(row)
          row && CommandTower::HomeNotices::NoticeRecord.from(row)
        end

        def dropped?(klass, row, disabled_keys)
          return true if disabled_keys.include?(klass.key)
          return true unless inside_class_window?(klass) && open_row?(row)

          klass < CommandTower::HomeNotices::Campaign && paced_out?(klass, row)
        end

        def inside_class_window?(klass)
          window = klass.window
          window.nil? || inside?(window.starts_at, window.ends_at)
        end

        def open_row?(row)
          return true if row.nil?

          inside?(row.starts_at, row.ends_at) &&
            row.acknowledged_at.nil? &&
            (row.dismissed_until.nil? || row.dismissed_until <= now)
        end

        def inside?(starts_at, ends_at)
          (starts_at.nil? || starts_at <= now) && (ends_at.nil? || ends_at > now)
        end

        def paced_out?(klass, row)
          impressions = klass.impressions
          return false if row.nil? || impressions.nil?

          at_period_max?(impressions, row) || inside_item_cooldown?(impressions, row)
        end

        def at_period_max?(impressions, row)
          !impressions.max.nil? && row.impression_count >= impressions.max
        end

        def inside_item_cooldown?(impressions, row)
          return false if impressions.cooldown.nil? || row.last_shown_at.nil?

          row.last_shown_at + impressions.cooldown > now
        end

        # Keys and counts only, never document content.
        def publish_selected(candidate_count, picks)
          publish("selected", user_id: user.id, candidate_count:,
                              blocking_key: picks[:blocking]&.notice_class&.key,
                              dismissible_key: picks[:dismissible]&.notice_class&.key, log_level: :info)
        end

        def publish(name, **payload)
          CommandTower::Events.publish(category: :home_notices, name:, payload:)
        end
      end
    end
  end
end
