# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::LoginRateLimits::FailOpen do
  describe ".increment" do
    it "counts within a window and reports a positive ttl" do
      described_class.increment(key: "k", ttl_seconds: 60)
      count, ttl = described_class.increment(key: "k", ttl_seconds: 60)

      expect([count, ttl.positive?]).to eq([2, true])
    end

    context "when the previous window expired" do
      before { allow(described_class).to receive(:monotonic_now).and_return(100.0, 200.0) }

      it "starts a fresh window" do
        described_class.increment(key: "k", ttl_seconds: 60)

        expect(described_class.increment(key: "k", ttl_seconds: 60).first).to eq(1)
      end
    end
  end

  describe "Redis outage" do
    let(:limits) { CommandTower.config.login.rate_limits }
    let(:lockout) { CommandTower::Services::Auth::LoginRateLimits::Lockout.new(subject: "user:1") }

    before do
      allow(limits).to receive(:ip_attempts).and_return(2)
    end

    [Redis::CannotConnectError, Redis::TimeoutError, Timeout::Error].each do |error_class|
      context "when Redis raises #{error_class}" do
        before do
          allow(CommandTower::RedisConnection).to receive(:with).and_raise(error_class)
          allow(CommandTower::Events).to receive(:publish)
        end

        it "allows IP attempts up to the in-process ceiling without raising" do
          2.times { expect(CommandTower::Services::Auth::LoginRateLimits::CheckIp.call(client_ip: "203.0.113.7")).to be_success }
        end

        it "rejects past the in-process ceiling with a rate-limit error, not a 500" do
          3.times { CommandTower::Services::Auth::LoginRateLimits::CheckIp.call(client_ip: "203.0.113.7") }

          expect(CommandTower::Services::Auth::LoginRateLimits::CheckIp.call(client_ip: "203.0.113.7").errors)
            .to contain_exactly(an_instance_of(CommandTower::Errors::Auth::AuthRateLimitedError))
        end

        it "does not lock the account" do
          expect([lockout.record_failure.locked?, lockout.status.locked?]).to eq([false, false])
        end

        it "publishes auth.rate_limit.fail_open" do
          CommandTower::Services::Auth::LoginRateLimits::CheckIp.call(client_ip: "203.0.113.7")

          expect(CommandTower::Events).to have_received(:publish)
            .with(hash_including(category: :auth, name: "rate_limit.fail_open"))
        end
      end
    end
  end
end
