# frozen_string_literal: true

# Login counters (per account and per IP) live in Redis and outlive an example's
# DB transaction. Without a reset, logins across the suite would share one IP
# bucket and trip it.

# Redis inspection helpers for lockout specs. Expects `lockout` and `max` to be
# defined by the including example group.
module LoginRateLimitsHelpers
  def redis_keys(pattern)
    CommandTower::RedisConnection.with { |redis| redis.keys(pattern) }
  end

  def redis_values(pattern)
    CommandTower::RedisConnection.with { |redis| redis.keys(pattern).map { |key| redis.get(key) } }
  end

  def lock_ttl
    CommandTower::RedisConnection.with { |redis| redis.keys("auth:login:lock:*").map { |key| redis.ttl(key) }.first }
  end

  def trip!
    max.times { lockout.record_failure }
  end

  def expire_lock!
    CommandTower::RedisConnection.with { |redis| redis.keys("auth:login:lock:*").each { |key| redis.del(key) } }
  end

  def lock_lengths(count)
    Array.new(count) do
      trip!
      lockout.status.retry_after.tap { expire_lock! }
    end
  end

  # Plain-text login attempts against the Login service.
  def login_attempt(identifier:, password:)
    CommandTower::Services::Auth::PlainText::Login.call(identifier:, password:)
  end

  def trip_login_lock(identifier)
    (max - 1).times { login_attempt(identifier:, password: "wrong-password") }
    login_attempt(identifier:, password: "wrong-password")
  end
end

RSpec.configure do |config|
  config.include LoginRateLimitsHelpers

  config.before do
    CommandTower::Services::Auth::LoginRateLimits::FailOpen.reset!
    CommandTower::RedisConnection.with(&:flushdb)
  rescue Redis::BaseError, KeyError
    nil
  end
end
