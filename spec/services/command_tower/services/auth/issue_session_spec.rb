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

  it "returns the installation id it started the session with" do
    expect(result.data[:installation_id]).to eq(installation_id)
  end

  context "with a boundary installation id" do
    let(:boundary_id) { "7b0f3a52-1c4e-4d6a-9b21-3f5e8c2d1a90" }

    it "falls back to the boundary installation id" do
      CommandTower::Current.set(installation_id: boundary_id, installation_id_source: :cookie) do
        expect(described_class.call(user:).data[:installation_id]).to eq(boundary_id)
      end
    end
  end
end
