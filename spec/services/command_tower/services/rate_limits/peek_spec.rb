# frozen_string_literal: true

RSpec.describe CommandTower::Services::RateLimits::Peek do
  let(:key) { "test:rate:#{SecureRandom.uuid}" }

  describe ".call" do
    subject(:result) { described_class.call(key:) }

    context "when the key does not exist" do
      it { expect(result).to be_success }
      it { expect(result.data[:count]).to eq(0) }
      it { expect(result.data[:ttl]).to eq(0) }
    end

    context "when the key has been checked" do
      before { 2.times { CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: 30) } }

      it { expect(result.data[:count]).to eq(2) }
      it { expect(result.data[:ttl]).to be_between(1, 30) }

      it "does not increment" do
        2.times { described_class.call(key:) }
        expect(described_class.call(key:).data[:count]).to eq(2)
      end
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
