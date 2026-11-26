# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::DeviceSessions::RevokeAll do
  subject(:result) { described_class.call(user:, reason: "password_reset") }

  let(:user) { create(:user) }
  let!(:active) { create_list(:device_session, 2, user:) }
  let!(:other_users_session) { create(:device_session) }
  let!(:already_revoked) { create(:device_session, :revoked, user:) }

  it "reports the revoked count" do
    expect(result.data[:revoked_count]).to eq(2)
  end

  it "revokes every active session of the user" do
    result
    expect(active.map { |session| session.reload.revoked_reason }).to eq(%w[password_reset password_reset])
  end

  it "leaves other users' sessions active" do
    result
    expect(other_users_session.reload).not_to be_revoked
  end

  it "keeps the original reason on already-revoked sessions" do
    expect { result }.not_to(change { already_revoked.reload.revoked_reason })
  end

  it "rejects unknown reasons" do
    expect { described_class.call(user:, reason: "bogus") }.to raise_error(ArgumentError)
  end
end
