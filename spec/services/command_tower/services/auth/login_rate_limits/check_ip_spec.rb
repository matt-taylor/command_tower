# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::LoginRateLimits::CheckIp do
  let(:limits) { CommandTower.config.login.rate_limits }

  describe ".call" do
    subject(:result) { described_class.call(client_ip: "203.0.113.9") }

    context "with a ceiling of 3" do
      before { allow(limits).to receive(:ip_attempts).and_return(3) }

      it "allows attempts up to the ceiling" do
        3.times { expect(described_class.call(client_ip: "203.0.113.9")).to be_success }
      end

      it "rejects the attempt past the ceiling with an AuthRateLimitedError" do
        3.times { described_class.call(client_ip: "203.0.113.9") }

        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::Auth::AuthRateLimitedError))
      end
    end

    context "with a ceiling of 1" do
      before { allow(limits).to receive(:ip_attempts).and_return(1) }

      it "reports retry_after_seconds within the window" do
        2.times { described_class.call(client_ip: "203.0.113.9") }

        expect(result.errors.first.details[:retry_after_seconds]).to be_between(1, limits.ip_window_seconds)
      end

      it "keeps buckets per IP" do
        described_class.call(client_ip: "203.0.113.9")

        expect(described_class.call(client_ip: "203.0.113.10")).to be_success
      end
    end

    context "when ip_attempts is 0" do
      before { allow(limits).to receive(:ip_attempts).and_return(0) }

      it "is disabled" do
        5.times { expect(described_class.call(client_ip: "203.0.113.9")).to be_success }
      end
    end

    context "with a Redis error" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open" do
        expect(result).to be_success
      end
    end
  end
end
