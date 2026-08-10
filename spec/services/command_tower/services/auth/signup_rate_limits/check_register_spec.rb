# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupRateLimits::CheckRegister do
  let(:client_ip) { "203.0.113.10" }

  before { flush_signup_rate_limits! }

  describe ".call" do
    it "allows a fresh client ip" do
      expect(described_class.call(client_ip: client_ip)).to be_success
    end

    context "when the hourly ceiling is passed" do
      let(:limit) { CommandTower.config.signup_session.rate_limits.ip_register_hour }

      before { limit.times { described_class.call(client_ip: client_ip) } }

      subject(:result) { described_class.call(client_ip: client_ip) }

      it { expect(result).to be_failure }

      it "returns an ip rate limit error" do
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupIpRateLimitError)
        )
      end
    end
  end
end
