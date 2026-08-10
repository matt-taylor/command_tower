# frozen_string_literal: true

RSpec.describe CommandTower::Services::RateLimits::Check do
  let(:key) { "test:rate:#{SecureRandom.uuid}" }

  before { flush_signup_rate_limits! }

  describe ".call" do
    context "with a valid key" do
      subject(:result) { described_class.call(key:, ttl_seconds: 30) }

      it "returns count and ttl in the success payload" do
        expect(result).to be_success
        expect(result.data[:count]).to eq(1)
        expect(result.data[:ttl]).to be_positive
      end
    end

    context "when honoring caller-supplied ttl" do
      before { described_class.call(key:, ttl_seconds: 45) }

      subject(:ttl) { CommandTower::RedisConnection.with { |redis| redis.ttl(key) } }

      it "honors the caller-supplied ttl" do
        expect(ttl).to be_between(40, 45)
      end
    end

    context "when incrementing an existing key" do
      let!(:first_ttl) do
        described_class.call(key:, ttl_seconds: 60)
        CommandTower::RedisConnection.with { |redis| redis.ttl(key) }
      end

      before { sleep 1 }

      subject(:second) { described_class.call(key:, ttl_seconds: 60) }

      let(:second_ttl) { CommandTower::RedisConnection.with { |redis| redis.ttl(key) } }

      it "sets ttl only on the first increment" do
        expect(second.data[:count]).to eq(2)
        expect(second_ttl).to be < first_ttl
      end
    end

    context "with a missing key" do
      subject(:result) { described_class.call(ttl_seconds: 60) }

      it "returns a validation failure" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end

    context "when redis raises" do
      before do
        allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError)
      end

      subject(:result) { described_class.call(key:, ttl_seconds: 60) }

      it "returns an InternalError instead of propagating" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::InternalError))
      end
    end
  end
end
