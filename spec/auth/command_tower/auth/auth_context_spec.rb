# frozen_string_literal: true

RSpec.describe CommandTower::Auth::AuthContext do
  let(:user) { create(:user, roles: ["member"]) }

  describe ".new" do
    subject(:context) do
      described_class.new(
        user: user,
        token_expires_at: "2026-07-14 04:46:14 +0000",
        token_source: :header,
        roles: user.roles,
        principal_type: :user
      )
    end

    it { expect(context.user).to eq(user) }
    it { expect(context.token_source).to eq(:header) }
    it { expect(context.principal_type).to eq(:user) }

    it "defaults generated_token to nil" do
      expect(context.generated_token).to be_nil
    end

    it { expect(context.device_session).to be_nil }
    it { expect(context.legacy_token).to be(false) }
  end

  describe ".from_authenticate_session_result" do
    subject(:context) do
      described_class.from_authenticate_session_result(data: data, metadata: metadata)
    end

    let(:data) do
      { user: user, token_expires_at: "2026-07-14 04:46:14 +0000", generated_token: "regenerated" }
    end
    let(:metadata) { { token_source: :cookie } }

    it { expect(context.user).to eq(user) }
    it { expect(context.token_expires_at).to eq("2026-07-14 04:46:14 +0000") }
    it { expect(context.token_source).to eq(:cookie) }
    it { expect(context.roles).to eq(["member"]) }
    it { expect(context.principal_type).to eq(:user) }
    it { expect(context.generated_token).to eq("regenerated") }
    it { expect(context.legacy_token).to be(false) }

    context "with a device session" do
      let(:device_session) { create(:device_session, user:) }
      let(:data) do
        { user: user, token_expires_at: "2026-07-14 04:46:14 +0000", device_session:, legacy_token: false }
      end

      it { expect(context.device_session).to eq(device_session) }
    end

    context "with a legacy token" do
      let(:data) { { user: user, token_expires_at: "2026-07-14 04:46:14 +0000", legacy_token: true } }

      it { expect(context.legacy_token).to be(true) }
    end
  end
end
