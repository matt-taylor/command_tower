# frozen_string_literal: true

RSpec.describe CommandTower::Auth::DeviceSessions::PurgeEndedJob do
  let!(:ended) { create(:device_session, :revoked, revoked_at: 8.days.ago) }

  it "purges ended device sessions" do
    described_class.perform_now

    expect(CommandTower::Auth::DeviceSession.exists?(ended.id)).to be(false)
  end
end
