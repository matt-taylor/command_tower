# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Picks at most one blocking and one dismissible notice from `Select`'s candidates (design §3.4
      # steps 3 and 4, doc 03 §7 and §8).
      #
      # Inputs: `user`, `request_context` (a HomeNotices::Context; `now` is the clock) and
      # `candidates` (`Select::Candidate`s, already in priority order).
      #
      # Nothing is picked when the client catalog is below 2. Otherwise each severity takes the
      # first candidate that passes its gate, then `show?`, then `Compose` (which applies the
      # `:blocking_notice` or default profile and skips a notice that fails):
      # - blocking gate, the UTC daily cap: a notice already started (`first_shown_at` set) is always
      #   re-served until acknowledged; otherwise the user's rows of registered blocking notices
      #   first shown in the current UTC day must number below `blocking_daily_cap`. Concurrent
      #   requests can each start a different notice before either impression lands, so the cap can
      #   be exceeded by one per concurrent request (design D5, accepted).
      # - dismissible gate, the global cooldown: clear when `max(last_shown_at)` over the user's rows
      #   of registered dismissible notices, plus `global_cooldown`, is at or before `now`; or, for a
      #   delivery, when its `ends_at` is at or before the moment the cooldown clears. Blocking
      #   impressions do not start the cooldown.
      #
      # `show?` has a 50 ms budget: an overrun publishes `command_tower.home_notices.show_if_slow`
      # (key and ms) and the answer is still used. An exception means "not shown" and publishes
      # `show_if_failed` (key and error class; error level for blocking keys, warn otherwise).
      #
      # Success data is `{ blocking:, dismissible: }`, each a `Pick(notice_class, record, document,
      # content_hash)` or nil.
      class PickNotices < CommandTower::Services::ApplicationService
        Pick = Data.define(:notice_class, :record, :document, :content_hash)

        SHOW_BUDGET_MS = 50

        validate :user, is_a: User, required: true
        validate :request_context, is_a: CommandTower::HomeNotices::Context, required: true
        validate :candidates, is_a: Array, required: true

        def call
          context.blocking = pick(:blocking?) { |candidate| under_daily_cap?(candidate) }
          context.dismissible = pick(:dismissible?) { |candidate| cooldown_clear?(candidate) }
        end

        private

        def now
          request_context.now
        end

        def config
          CommandTower.config.home_notices
        end

        # First candidate of the severity that passes the gate (the block), `show?` and compose.
        def pick(severity_predicate)
          return nil if request_context.ui_catalog.to_i < Compose::MIN_CATALOG

          candidates.each do |candidate|
            next unless candidate.notice_class.public_send(severity_predicate)
            next unless yield(candidate) && shown?(candidate)

            composed = compose(candidate)
            return composed unless composed.nil?
          end
          nil
        end

        def under_daily_cap?(candidate)
          !candidate.record&.first_shown_at.nil? || blocking_started_today < config.blocking_daily_cap
        end

        def blocking_started_today
          @blocking_started_today ||= begin
            day = now.utc.beginning_of_day
            user_rows(:blocking?).where(first_shown_at: day...(day + 1.day)).count
          end
        end

        def cooldown_clear?(candidate)
          clears_at = global_cooldown_clears_at
          return true if clears_at.nil? || clears_at <= now

          ends_at = candidate.record&.ends_at
          candidate.notice_class < CommandTower::HomeNotices::Delivery && !ends_at.nil? && ends_at <= clears_at
        end

        def global_cooldown_clears_at
          return @global_cooldown_clears_at if defined?(@global_cooldown_clears_at)

          last_shown_at = user_rows(:dismissible?).maximum(:last_shown_at)
          @global_cooldown_clears_at = last_shown_at && (last_shown_at + config.global_cooldown)
        end

        # The user's rows whose key is a registered notice of the given severity.
        def user_rows(severity_predicate)
          keys = CommandTower::HomeNotices::Catalog.notices.select(&severity_predicate).map(&:key)
          CommandTower::HomeNotice.where(user_id: user.id, key: keys)
        end

        def shown?(candidate)
          klass = candidate.notice_class
          started_at = monotonic_seconds
          shown = klass.new.show?(user:, context: request_context, notice: candidate.record)
          report_slow(klass, started_at)
          shown ? true : false
        rescue StandardError => e
          publish("show_if_failed", notice_key: klass.key, error_class: e.class.name,
                                    log_level: klass.blocking? ? :error : :warn)
          false
        end

        def report_slow(klass, started_at)
          elapsed_ms = ((monotonic_seconds - started_at) * 1000).round
          return if elapsed_ms <= SHOW_BUDGET_MS

          publish("show_if_slow", notice_key: klass.key, ms: elapsed_ms, log_level: :warn)
        end

        def monotonic_seconds
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def compose(candidate)
          data = Compose.call(notice_class: candidate.notice_class, user:, request_context:,
                              record: candidate.record).data
          return nil if data[:document].nil?

          Pick.new(notice_class: candidate.notice_class, record: candidate.record,
                   document: data[:document], content_hash: data[:content_hash])
        end

        def publish(name, **payload)
          CommandTower::Events.publish(category: :home_notices, name:, payload:)
        end
      end
    end
  end
end
