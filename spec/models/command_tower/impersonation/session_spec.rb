# frozen_string_literal: true

RSpec.describe CommandTower::Impersonation::Session, type: :model do
  subject(:session) { create(:impersonation_session, actor:, target:) }

  let(:actor) { create(:user) }
  let(:target) { create(:user) }

  it "persists a uuid public id" do
    expect(session.id).to match(/\A[0-9a-f-]{36}\z/)
  end

  it "is open until ended" do
    expect(session.open?).to be(true)
  end

  context "when idle has passed" do
    subject(:session) do
      create(:impersonation_session, actor:, target:, idle_expires_at: 1.minute.ago, absolute_expires_at: 1.hour.from_now)
    end

    it "reports idle expiration" do
      expect(session.expired?).to be(true)
      expect(session.expiration_reason).to eq("idle_timeout")
    end
  end

  context "when absolute has passed" do
    subject(:session) do
      create(
        :impersonation_session,
        actor:,
        target:,
        idle_expires_at: 1.hour.from_now,
        absolute_expires_at: 1.minute.ago
      )
    end

    it "prefers absolute_timeout" do
      expect(session.expiration_reason).to eq("absolute_timeout")
    end
  end
end
