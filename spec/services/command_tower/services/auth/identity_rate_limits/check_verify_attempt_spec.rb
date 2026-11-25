# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::IdentityRateLimits::CheckVerifyAttempt do
  let(:limits) { CommandTower.config.login.rate_limits }
  let(:user) { create(:user, :unvalidated_email) }

  describe ".call" do
    context "with a ceiling of 3" do
      before { allow(limits).to receive(:verify_attempts).and_return(3) }

      it "allows attempts up to the ceiling" do
        3.times { expect(described_class.call(user: user)).to be_success }
      end
    end

    context "with a ceiling of 2" do
      before { allow(limits).to receive(:verify_attempts).and_return(2) }

      it "rejects the attempt past the ceiling with an AuthRateLimitedError" do
        2.times { described_class.call(user: user) }

        expect(described_class.call(user: user).errors)
          .to contain_exactly(an_instance_of(CommandTower::Errors::Auth::AuthRateLimitedError))
      end
    end

    context "with a ceiling of 1" do
      let(:other_user) { create(:user, :unvalidated_email) }

      before { allow(limits).to receive(:verify_attempts).and_return(1) }

      it "keeps buckets per user" do
        described_class.call(user: user)

        expect(described_class.call(user: other_user)).to be_success
      end
    end

    context "when verify_attempts is 0" do
      before { allow(limits).to receive(:verify_attempts).and_return(0) }

      it "is disabled" do
        5.times { expect(described_class.call(user: user)).to be_success }
      end
    end

    context "with a Redis error" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open" do
        expect(described_class.call(user: user)).to be_success
      end
    end
  end
end
