# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupRateLimits::CheckAvailability do
  let(:client_ip) { "203.0.113.10" }
  let(:signup_session) { signup_session_context(client_ip: client_ip) }

  before { flush_signup_rate_limits! }

  describe ".call" do
    context "with repeated requests on the same jti" do
      subject(:first) { described_class.call(signup_session: signup_session, kind: :email) }

      before do
        first
        described_class.call(signup_session: signup_session, kind: :email)
      end

      it "increments the same jti counters for repeated requests" do
        expect(first).to be_success

        CommandTower::RedisConnection.with do |redis|
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:email").to_i).to eq(2)
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:total").to_i).to eq(2)
        end
      end
    end

    context "with different jti values" do
      let(:other_session) { signup_session_context(client_ip: client_ip) }

      before do
        described_class.call(signup_session: signup_session, kind: :email)
        described_class.call(signup_session: other_session, kind: :email)
      end

      it "uses different counters for different jti values" do
        CommandTower::RedisConnection.with do |redis|
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:email").to_i).to eq(1)
          expect(redis.get("signup:rate:jti:#{other_session.jti}:email").to_i).to eq(1)
        end
      end
    end

    context "when tracking email, username, and total counters" do
      before do
        described_class.call(signup_session: signup_session, kind: :email)
        described_class.call(signup_session: signup_session, kind: :username)
      end

      it "tracks email, username, and total counters independently" do
        CommandTower::RedisConnection.with do |redis|
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:email").to_i).to eq(1)
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:username").to_i).to eq(1)
          expect(redis.get("signup:rate:jti:#{signup_session.jti}:total").to_i).to eq(2)
        end
      end
    end

    context "after a single email check" do
      before { described_class.call(signup_session: signup_session, kind: :email) }

      it "never writes raw jwt material into redis keys" do
        CommandTower::RedisConnection.with do |redis|
          expect(redis.keys("signup:rate:jti:#{signup_session.jti}:*")).not_to be_empty
          expect(redis.keys("signup:rate:jti:#{signup_session.jti}:*")).to all(include(signup_session.jti))
          expect(redis.keys("signup:rate:jti:#{signup_session.jti}:*").none? { |key| key.include?("eyJ") }).to be(true)
        end
      end
    end

    context "with an expired signup session" do
      let(:expired_session) { signup_session_context(expires_at: 1.minute.ago.utc, client_ip: client_ip) }

      subject(:result) { described_class.call(signup_session: expired_session, kind: :email) }

      it "rejects expired signup sessions without creating redis keys" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionExpiredError)
        )
        CommandTower::RedisConnection.with do |redis|
          expect(redis.keys("signup:rate:jti:#{expired_session.jti}:*")).to be_empty
        end
      end
    end

    context "when the per-kind ceiling is exceeded" do
      let(:limit) { CommandTower.config.signup_session.rate_limits.jti_email }

      before { limit.times { described_class.call(signup_session: signup_session, kind: :email) } }

      subject(:result) { described_class.call(signup_session: signup_session, kind: :email) }

      it "fails with a session rate limit once the per-kind ceiling is passed" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionRateLimitError)
        )
      end
    end

    context "with an unsupported kind" do
      subject(:result) { described_class.call(signup_session: signup_session, kind: :phone) }

      it "fails argument validation" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
