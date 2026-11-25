# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::DeviceSessions::PurgeEndedWorkflow do
  let(:user) { create(:user) }
  let(:ids_remaining) { CommandTower::Auth::DeviceSession.pluck(:id) }

  context "with a session revoked longer ago than the retention window" do
    let!(:old) { create(:device_session, :revoked, user:, revoked_at: 31.days.ago) }

    it "deletes it" do
      described_class.call

      expect(ids_remaining).not_to include(old.id)
    end
  end

  context "with a recently revoked session" do
    let!(:recent) { create(:device_session, :revoked, user:, revoked_at: 29.days.ago) }

    it "keeps it" do
      described_class.call

      expect(ids_remaining).to include(recent.id)
    end
  end

  context "with a session past absolute expiry beyond the retention window" do
    let!(:expired) { create(:device_session, user:, absolute_expires_at: 31.days.ago) }

    it "deletes it" do
      described_class.call

      expect(ids_remaining).not_to include(expired.id)
    end
  end

  context "with a live session" do
    let!(:live) { create(:device_session, user:) }

    it "keeps it" do
      described_class.call

      expect(ids_remaining).to include(live.id)
    end
  end

  context "with one revoked and one expired session" do
    before do
      create(:device_session, :revoked, user:, revoked_at: 31.days.ago)
      create(:device_session, user:, absolute_expires_at: 32.days.ago)
    end

    it "reports the purged count" do
      expect(described_class.call.payload).to eq(purged: 2)
    end
  end

  context "with more rows than one batch" do
    before do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      create_list(:device_session, 5, :revoked, user:, revoked_at: 31.days.ago)
    end

    it "works through all of them" do
      expect(described_class.call.payload).to eq(purged: 5)
    end
  end
end
