# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ErrorStatus do
  describe ".http_status_for" do
    subject(:status) { described_class.http_status_for(error) }

    context "with AuthRateLimitedError" do
      let(:error) { CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: 30) }

      it { is_expected.to eq(:too_many_requests) }
    end

    context "with an unmapped error" do
      let(:error) { CommandTower::Errors::NotFoundError.new }

      it { is_expected.to eq(:internal_server_error) }
    end
  end
end
