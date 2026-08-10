# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::EmailVerification::Required do
  before { user.update(created_at:) }
  let(:created_at) { 5.minutes.from_now }
  let(:user) { create(:user, :unvalidated_email) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it "returns a requirement value object" do
      expect(call).to be_a(described_class::Requirement)
    end

    it "sets required_after_time" do
      expect(call.required_after_time).to be_a(Time)
    end

    it "sets required false" do
      expect(call.required).to eq(false)
      expect(call).not_to be_required
    end

    context "when the grace period has passed" do
      let(:created_at) { 5.minutes.ago }

      it "returns a requirement value object" do
        expect(call).to be_a(described_class::Requirement)
      end

      it "sets required_after_time" do
        expect(call.required_after_time).to be_a(Time)
      end

      it "sets required true" do
        expect(call.required).to eq(true)
        expect(call).to be_required
      end
    end
  end
end
