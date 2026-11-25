# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::DeviceSessions::Start do
  subject(:result) { described_class.call(**params) }

  let(:user) { create(:user) }
  let(:installation_id) { SecureRandom.uuid }
  let(:params) { { user:, installation_id:, platform: "ios", app_version: "1.2.3" } }
  let(:device_session) { result.data[:device_session] }

  it { expect(result).to be_success }

  it "persists the device attributes" do
    expect(device_session).to have_attributes(
      user_id: user.id, installation_id:, platform: "ios", app_version: "1.2.3"
    )
  end

  it "sets absolute expiry from config" do
    expect(device_session.absolute_expires_at)
      .to be_within(5.seconds).of(CommandTower.config.session.absolute_timeout.from_now)
  end

  it "stamps last_seen_at" do
    expect(device_session.last_seen_at).to be_within(5.seconds).of(Time.current)
  end

  context "when called without device attributes" do
    let(:params) { { user: } }

    it { expect(result).to be_success }

    it "leaves device attributes nil" do
      expect(device_session).to have_attributes(installation_id: nil, platform: nil, app_version: nil)
    end
  end

  context "when the installation already has an active session" do
    let!(:previous) { create(:device_session, user:, installation_id:) }

    before { result }

    it "revokes the previous session as replaced" do
      expect(previous.reload).to have_attributes(revoked_reason: "replaced")
    end

    it "marks the previous session revoked" do
      expect(previous.reload.revoked?).to be(true)
    end

    it "leaves the new session active" do
      expect(device_session.reload.revoked?).to be(false)
    end
  end

  context "when another installation or user holds a session" do
    let!(:others) do
      [create(:device_session, user:, installation_id: SecureRandom.uuid), create(:device_session, installation_id:)]
    end

    before { result }

    it "keeps the other installation active" do
      expect(others.first.reload.revoked?).to be(false)
    end

    it "keeps another user's session active" do
      expect(others.last.reload.revoked?).to be(false)
    end
  end

  context "when called without installation_id twice" do
    let(:params) { { user: } }

    let!(:first) { described_class.call(user:).data[:device_session] }

    it "keeps both sessions active" do
      described_class.call(user:)
      expect(first.reload.revoked?).to be(false)
    end
  end

  context "when user is missing" do
    let(:params) { { installation_id: } }

    it { expect(result).to be_failure }
  end
end
