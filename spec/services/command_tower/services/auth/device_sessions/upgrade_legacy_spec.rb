# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::DeviceSessions::UpgradeLegacy do
  subject(:result) { described_class.call(user:, legacy_generated_at:, installation_id:) }

  let(:user) { create(:user) }
  let(:legacy_generated_at) { 2.days.ago.to_i }
  let(:installation_id) { SecureRandom.uuid }
  let(:device_session) { result.data[:device_session] }

  it { expect(result).to be_success }

  it "keys the row by the token's generated_at and carries the installation" do
    expect(device_session).to have_attributes(
      user_id: user.id,
      installation_id:,
      legacy_generated_at: Time.zone.at(legacy_generated_at)
    )
  end

  it "expires at generated_at plus the absolute timeout" do
    expect(device_session.absolute_expires_at)
      .to eq(Time.zone.at(legacy_generated_at) + CommandTower.config.session.absolute_timeout)
  end

  context "when upgraded twice" do
    let(:first_session) { described_class.call(user:, legacy_generated_at:).data[:device_session] }

    before { first_session }

    it "returns the same row" do
      expect(device_session.id).to eq(first_session.id)
    end
  end

  it "creates one row when upgraded twice" do
    described_class.call(user:, legacy_generated_at:)

    expect { result }.not_to change(CommandTower::Auth::DeviceSession, :count)
  end
end
