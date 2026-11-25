# frozen_string_literal: true

# Callers for the ResolveNotice and CheckMutationEligibility specs. Example groups cannot define
# `def` helpers (test standards guard), so the calls are built here.
module HomeNoticeMutationSpecHelpers
  module_function

  def mutation_context
    HomeNoticeSelectSpecHelpers.request_context(now: HomeNoticeSelectSpecHelpers.start_time)
  end

  def resolve_notice(user:, public_id: nil, campaign_key: nil)
    notice_id = CommandTower::Deserializers::HomeNotices::NoticeIdDeserializer::Input.new(public_id:, campaign_key:)
    CommandTower::Services::HomeNotices::ResolveNotice.call(user:, notice_id:, request_context: mutation_context)
  end

  def check_eligibility(notice_class:, row: nil, for_impression: false)
    CommandTower::Services::HomeNotices::CheckMutationEligibility.call(
      notice_class:, row:, for_impression:, request_context: mutation_context
    )
  end

  def record_impression(user:, notice_class:, row: nil, period_key: "week-48", **options)
    at = options.fetch(:at, HomeNoticeSelectSpecHelpers.start_time)
    impersonating = options.fetch(:impersonating, false)
    request_context = HomeNoticeSelectSpecHelpers.request_context(now: at).with(impersonating:)
    CommandTower::Services::HomeNotices::RecordImpression.call(
      user:, notice_class:, row:, period_key:, request_context:
    )
  end

  def impression_audits
    CommandTower::Audit::Event.where(action: "home_notice_impression")
  end

  def campaign_rows(campaign_key)
    CommandTower::HomeNotice.where(campaign_key:)
  end

  # Runs the block on `count` threads released together, each on its own connection, and returns
  # their values (a thread's exception is raised here). Needs `with_concurrent_pool`. Memoized lets
  # are not thread-safe: evaluate them before the call and pass plain values into the block.
  def concurrently(count: 2, &)
    barrier = Queue.new
    threads = Array.new(count) do
      Thread.new do
        Thread.current.report_on_exception = false
        barrier.pop
        ActiveRecord::Base.connection_pool.with_connection(&)
      end
    end
    count.times { barrier << :go }
    threads.map(&:value)
  end

  # Real concurrency needs separate connections that see each other's commits: the test pool holds
  # one connection and DatabaseCleaner wraps each example in a transaction. This widens the pool and
  # cleans by truncation for the block. Wrap the example from an `around` hook in a group with
  # `self.use_transactional_tests = false`.
  def with_concurrent_pool(size: 3)
    db_config = ActiveRecord::Base.connection_db_config
    cleaner = DatabaseCleaner[:active_record]
    strategy = cleaner.strategy
    cleaner.strategy = :truncation
    ActiveRecord::Base.establish_connection(db_config.configuration_hash.merge(pool: size))
    yield
  ensure
    ActiveRecord::Base.establish_connection(db_config)
    cleaner.strategy = strategy
  end
end
