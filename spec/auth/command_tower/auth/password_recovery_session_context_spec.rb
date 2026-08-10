# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PasswordRecoverySessionContext do
  subject(:context) { described_class.new(jti: "jti-1", expires_at: expires_at, client_ip: "203.0.113.7") }

  let(:expires_at) { 5.minutes.from_now.utc }

  it { expect(context.jti).to eq("jti-1") }
  it { expect(context.client_ip).to eq("203.0.113.7") }

  describe "#remaining_seconds" do
    it "reports the time left on the session" do
      expect(context.remaining_seconds).to eq(300)
    end

    context "when the session already expired" do
      let(:expires_at) { 1.minute.ago.utc }

      it "floors at zero" do
        expect(context.remaining_seconds).to eq(0)
      end
    end
  end
end
