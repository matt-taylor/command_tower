# frozen_string_literal: true

RSpec.describe CommandTower::Services::RateLimits::Clear do
  let(:key) { "test:rate:#{SecureRandom.uuid}" }

  describe ".call" do
    subject(:result) { described_class.call(key:) }

    context "when the key has a counter" do
      before { 3.times { CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: 30) } }

      it { expect(result).to be_success }

      it "removes the counter" do
        result
        expect(CommandTower::Services::RateLimits::Peek.call(key:).data[:count]).to eq(0)
      end

      it "lets the next check start a fresh window" do
        result
        expect(CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: 30).data[:count]).to eq(1)
      end
    end

    context "when the key does not exist" do
      it { expect(result).to be_success }
    end

    context "with a missing key" do
      subject(:result) { described_class.call }

      it { expect(result).to be_failure }
      it { expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError)) }
    end

    context "when redis raises" do
      before do
        allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError)
      end

      it { expect(result).to be_failure }
      it { expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::InternalError)) }
    end
  end
end
