# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::ExperienceStates::CheckCompleteRateLimit do
  let(:user) { create(:user) }

  before do
    flush_signup_rate_limits!
    allow(CommandTower.config.registry.experience_states).to receive(:complete_rate)
      .and_return({ limit: 2, window: 60 })
  end

  describe ".call" do
    it "allows requests under the limit" do
      2.times { expect(described_class.call(user:)).to be_success }
    end

    context "when over the limit" do
      subject(:result) { described_class.call(user:) }

      before { 2.times { described_class.call(user:) } }

      it "fails with a rate limited error carrying retry_after_seconds", :aggregate_failures do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStateRateLimited)
        expect(result.errors.first.details[:retry_after_seconds]).to be_between(1, 60)
      end
    end

    context "when the limiter fails" do
      let(:events) { [] }
      let(:subscription) do
        ActiveSupport::Notifications.subscribe(/rate_limiter_unavailable/) { |*args| events << args.last }
      end

      before do
        subscription
        allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError)
      end

      after { ActiveSupport::Notifications.unsubscribe(subscription) }

      it "allows the request and publishes the user id only", :aggregate_failures do
        expect(described_class.call(user:)).to be_success
        expect(events.size).to eq(1)
        expect(events.first).to include(user_id: user.id, error_class: "Redis::CannotConnectError")
        expect(events.first.keys).not_to include(:experience_key, :scope_identifier)
      end
    end
  end
end
