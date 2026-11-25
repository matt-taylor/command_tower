# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::AuthenticationResponseEffects do
  describe ".for_set_token" do
    subject(:effects) { described_class.for_set_token(token: "t", expires_at: "soon", device_session:) }

    context "with a device session" do
      let(:device_session) { build(:device_session, absolute_expires_at: 90.days.from_now) }

      it "carries the device session's absolute expiry as the cookie expiry" do
        expect(effects).to eq(token: "t", expires_at: "soon", header: true,
                              cookie_expires_at: device_session.absolute_expires_at)
      end
    end

    context "without a device session" do
      let(:device_session) { nil }

      it "leaves the cookie expiry unset" do
        expect(effects[:cookie_expires_at]).to be_nil
      end
    end
  end

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

    context "when a cookie authenticated request failed because email is unverified" do
      let(:metadata) do
        {
          cookie_authenticated: true,
          authentication_failed: true,
          email_verification_required: true
        }
      end

      it { is_expected.to eq({}) }
    end

    context "when a cookie authenticated request failed because impersonation expired" do
      let(:metadata) do
        {
          cookie_authenticated: true,
          authentication_failed: true,
          impersonation_session_expired: true
        }
      end

      it { is_expected.to eq({}) }
    end
  end
end
