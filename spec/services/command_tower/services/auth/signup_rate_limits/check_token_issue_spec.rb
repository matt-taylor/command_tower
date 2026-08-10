# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupRateLimits::CheckTokenIssue do
  let(:client_ip) { "203.0.113.10" }

  before { flush_signup_rate_limits! }

  describe ".call" do
    context "within the burst ceiling" do
      let(:limit) { CommandTower.config.signup_session.rate_limits.ip_issue_burst }

      subject(:results) { Array.new(limit) { described_class.call(client_ip: client_ip) } }

      it "allows requests up to the burst ceiling" do
        expect(results).to all(be_success)
      end
    end

    context "beyond the burst ceiling" do
      let(:limit) { CommandTower.config.signup_session.rate_limits.ip_issue_burst }

      before { limit.times { described_class.call(client_ip: client_ip) } }

      subject(:result) { described_class.call(client_ip: client_ip) }

      it "fails with an ip rate limit once the burst ceiling is passed" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupIpRateLimitError)
        )
        expect(result.errors.first.details[:retry_after_seconds]).to be_positive
      end
    end

    context "without a client ip" do
      subject(:result) { described_class.call }

      it "fails argument validation" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
