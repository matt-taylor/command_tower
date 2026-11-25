# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::IssueSession do
  subject(:result) { described_class.call(user:, installation_id:, platform: "ios") }

  let(:user) { create(:user) }
  let(:installation_id) { SecureRandom.uuid }
  let(:payload) { CommandTower::Jwt::Decode.call(token: result.data[:token]).payload }

  it { expect(result).to be_success }

  it "creates a device session for the user" do
    expect { result }.to change { CommandTower::Auth::DeviceSession.where(user_id: user.id).count }.by(1)
  end

  it "mints a token whose sid is the device session public id" do
    expect(payload[:sid]).to eq(result.data[:device_session].public_id)
  end

  it "returns the token expiry" do
    expect(result.data[:expires_at]).to be_present
  end
end
