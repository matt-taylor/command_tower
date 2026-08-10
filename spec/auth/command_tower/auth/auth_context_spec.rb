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
  end
end
