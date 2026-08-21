# frozen_string_literal: true

RSpec.describe CommandTower::Services::Impersonation::RecordActivity do
  describe ".call" do
    subject(:result) { described_class.call(session_id: session.id) }

    let(:actor) { create(:user) }
    let(:target) { create(:user) }
    let!(:session) do
      create(
        :impersonation_session,
        actor:,
        target:,
        idle_expires_at: 2.minutes.from_now,
        absolute_expires_at: 1.hour.from_now
      )
    end
    let!(:idle_before) { session.idle_expires_at }
    let!(:absolute_before) { session.absolute_expires_at }

    it "extends idle without changing absolute" do
      expect(result).to be_success
      expect(result.data[:refreshed]).to be(true)
      expect(session.reload.idle_expires_at).to be > idle_before
      expect(session.absolute_expires_at).to eq(absolute_before)
    end

    context "when the session is ended" do
      let!(:session) { create(:impersonation_session, :ended, actor:, target:) }

      it "does not refresh" do
        expect(result.data[:refreshed]).to be(false)
      end
    end
  end
end
