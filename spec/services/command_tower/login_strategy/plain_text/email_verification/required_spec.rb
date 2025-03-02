# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::EmailVerification::Required do
  before { user.update(created_at:) }
  let(:created_at) { 5.minutes.from_now }
  let(:user) { create(:user, :unvalidated_email) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets reqired_after_time" do
      expect(call.reqired_after_time).to be_a(Time)
    end

    it "sets required false" do
      expect(call.required).to eq(false)
    end

    context "when invalid" do
      let(:created_at) { 5.minutes.ago }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets reqired_after_time" do
        expect(call.reqired_after_time).to be_a(Time)
      end

      it "sets required true" do
        expect(call.required).to eq(true)
      end
    end
  end
end
