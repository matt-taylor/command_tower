# frozen_string_literal: true

RSpec.describe CommandTower::Auth::DeviceSession, type: :model do
  subject(:device_session) { create(:device_session, user:) }

  let(:user) { create(:user) }

  it "assigns a uuid public id" do
    expect(device_session.public_id).to match(/\A[0-9a-f-]{36}\z/)
  end

  it "is not revoked by default" do
    expect(device_session.revoked?).to be(false)
  end

  it "includes unrevoked sessions in active" do
    expect(described_class.active).to include(device_session)
  end

  it "reports revoked sessions" do
    expect(create(:device_session, :revoked, user:).revoked?).to be(true)
  end

  it "excludes revoked sessions from active" do
    expect(described_class.active).not_to include(create(:device_session, :revoked, user:))
  end

  it "rejects an unknown revoked reason" do
    device_session.revoked_reason = "bogus"

    expect(device_session).not_to be_valid
  end

  context "with an existing session for a legacy_generated_at" do
    let(:at) { Time.current.change(usec: 0) }

    let(:duplicate) { build(:device_session, user:, public_id: SecureRandom.uuid, legacy_generated_at: at) }

    before { create(:device_session, user:, legacy_generated_at: at) }

    it "allows only one session per user and legacy_generated_at" do
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
