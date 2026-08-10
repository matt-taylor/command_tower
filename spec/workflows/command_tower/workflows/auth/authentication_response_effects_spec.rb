# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::AuthenticationResponseEffects do
  describe ".for_auth_failure" do
    subject(:effects) { described_class.for_auth_failure(metadata) }

    context "when a cookie authenticated request failed" do
      let(:metadata) { { cookie_authenticated: true, authentication_failed: true } }

      it { is_expected.to eq(clear_auth_cookie: true) }
    end

    context "when a bearer authenticated request failed" do
      let(:metadata) { { cookie_authenticated: false, authentication_failed: true } }

      it { is_expected.to eq({}) }
    end

    context "when a cookie authenticated request succeeded" do
      let(:metadata) { { cookie_authenticated: true, authentication_failed: false } }

      it { is_expected.to eq({}) }
    end
  end
end
