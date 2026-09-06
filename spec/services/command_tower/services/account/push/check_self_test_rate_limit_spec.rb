# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::CheckSelfTestRateLimit do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }
    let(:previous_limit) { CommandTower.config.messaging.expo.self_test_per_user_hour }
    let(:previous_window) { CommandTower.config.messaging.expo.self_test_window_seconds }

    around do |example|
      CommandTower.config.messaging.expo.self_test_per_user_hour = 2
      CommandTower.config.messaging.expo.self_test_window_seconds = 3600
      example.run
    ensure
      CommandTower.config.messaging.expo.self_test_per_user_hour = previous_limit
      CommandTower.config.messaging.expo.self_test_window_seconds = previous_window
    end

    context "when under the configured limit" do
      before { described_class.call(user:) }

      it { expect(result).to be_success }
    end

    context "when the configured limit is exceeded" do
      before do
        2.times { described_class.call(user:) }
      end

      it "fails with push_test_rate_limited" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushTestRateLimitError)
        expect(result.errors.first.code).to eq("push_test_rate_limited")
        expect(result.errors.first.details).to include(:retry_after_seconds)
      end
    end

    context "when the configured limit is raised" do
      before do
        2.times { described_class.call(user:) }
        CommandTower.config.messaging.expo.self_test_per_user_hour = 3
      end

      it "honors the new configured ceiling" do
        expect(result).to be_success
      end
    end
  end
end
