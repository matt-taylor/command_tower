# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::LoginRateLimits::Lockout do
  subject(:lockout) { described_class.new(subject: "user:1") }

  let(:limits) { CommandTower.config.login.rate_limits }
  let(:max) { limits.account_failures }

  describe ".subject_for" do
    let(:user) { build_stubbed(:user) }

    it "uses the user id when the user exists" do
      expect(described_class.subject_for(user:, identifier: "A@x.com")).to eq("user:#{user.id}")
    end

    it "uses the normalized identifier otherwise" do
      expect(described_class.subject_for(user: nil, identifier: " Nobody@X.com ")).to eq("identifier:nobody@x.com")
    end
  end

  describe "#record_failure" do
    it "does not lock below the threshold" do
      (max - 1).times { lockout.record_failure }
      expect(lockout.status).not_to be_locked
    end

    context "when the threshold is reached" do
      let(:result) { lockout.record_failure }

      before { (max - 1).times { lockout.record_failure } }

      it "locks on the failure that reaches the threshold", :aggregate_failures do
        expect(result).to be_locked
        expect(result.retry_after).to eq(limits.lock_base_seconds)
        expect(lockout.status).to be_locked
      end
    end

    context "when hammered while locked" do
      before { trip! }

      let!(:ttl_before) { lock_ttl }

      it "does not count failures, so hammering cannot extend the lock", :aggregate_failures do
        expect(Array.new(5) { lockout.record_failure }).to all(be_locked)
        expect(redis_keys("auth:login:fail:*") + redis_values("auth:login:level:*")).to eq(["1"])
        expect(lock_ttl).to be <= ttl_before
      end
    end

    it "stores no plaintext subject in Redis keys", :aggregate_failures do
      trip!

      expect(redis_keys("auth:login:*")).not_to be_empty
      expect(redis_keys("auth:login:*").join).not_to include("user:1")
    end

    context "when account_failures is 0" do
      before { allow(limits).to receive(:account_failures).and_return(0) }

      it "does nothing" do
        expect(Array.new(20) { lockout.record_failure }).to all(satisfy { |result| !result.locked? })
      end
    end

    context "with a Redis error" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open", :aggregate_failures do
        expect(lockout.record_failure).not_to be_locked
        expect(lockout.status).not_to be_locked
      end
    end

    context "when failures arrive concurrently" do
      let(:results) do
        Array.new(max * 2) do
          Thread.new { described_class.new(subject: "user:1").record_failure }
        end.map(&:value)
      end

      it "trips the lock exactly once", :aggregate_failures do
        # The tripping failure plus every later one reports locked: no more, no fewer.
        expect(results.count(&:locked?)).to eq(max + 1)
        expect(redis_values("auth:login:level:*")).to eq(["1"])
      end
    end
  end

  describe "progressive levels" do
    let(:base) { limits.lock_base_seconds }
    let(:expected) { [1, 2, 4, 8].map { |factor| [base * factor, limits.lock_max_seconds].min } }

    it "doubles the lock each time it trips again, capped at the maximum" do
      expect(lock_lengths(4)).to match(expected.map { |want| be_between(want - 2, want) })
    end

    it "starts a fresh count after a lock expires" do
      trip!
      expire_lock!

      expect(lockout.record_failure).not_to be_locked
    end
  end

  describe "#clear" do
    it "clears the failure streak but keeps a lock" do
      trip!
      lockout.clear

      expect(lockout.status).to be_locked
    end

    it "restarts the threshold after the streak is cleared" do
      (max - 1).times { lockout.record_failure }
      lockout.clear

      expect(lockout.record_failure).not_to be_locked
    end

    it "drops the lock and the level when asked", :aggregate_failures do
      trip!
      lockout.clear(lock_and_level: true)

      expect(lockout.status).not_to be_locked
      expect(redis_keys("auth:login:*")).to be_empty
    end
  end
end
