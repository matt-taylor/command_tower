# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::IdentityRateLimits::CheckVerificationSend do
  let(:limits) { CommandTower.config.login.rate_limits }
  let(:user) { create(:user, :unvalidated_email) }

  describe ".call" do
    subject(:result) { described_class.call(user: user) }

    it "lets the first request send" do
      expect(result.data[:quiet]).to be(false)
    end

    it "reports when a resend opens" do
      expect(result.data[:resend_available_at]).to be_within(2.seconds).of(60.seconds.from_now)
    end

    context "with a repeat request inside the quiet window" do
      subject(:second) { described_class.call(user: user) }

      before { described_class.call(user: user) }

      it { expect(second).to be_success }
      it { expect(second.data[:quiet]).to be(true) }

      it "keeps resend_available_at at the end of the window" do
        expect(second.data[:resend_available_at]).to be_within(3.seconds).of(60.seconds.from_now)
      end
    end

    context "with an hourly cap of 1" do
      before { allow(limits).to receive(:verify_send_per_hour).and_return(1) }

      it "does not count quiet requests toward the hourly cap" do
        described_class.call(user: user)

        3.times { expect(described_class.call(user: user)).to be_success }
      end
    end

    context "with no quiet window and an hourly cap of 2" do
      before { allow(limits).to receive_messages(verify_send_quiet_seconds: 0, verify_send_per_hour: 2) }

      it "rejects a send past the hourly cap with an AuthRateLimitedError" do
        2.times { described_class.call(user: user) }

        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::Auth::AuthRateLimitedError))
      end
    end

    context "when the quiet window is 0" do
      before { allow(limits).to receive(:verify_send_quiet_seconds).and_return(0) }

      it "is never quiet" do
        described_class.call(user: user)

        expect(result.data[:quiet]).to be(false)
      end
    end

    context "with a Redis error" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open" do
        expect(result.data[:quiet]).to be(false)
      end
    end
  end
end
