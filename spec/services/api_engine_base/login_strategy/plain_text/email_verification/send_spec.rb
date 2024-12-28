# frozen_string_literal: true

RSpec.describe ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Send do
  let(:user) { create(:user, :unvalidated_email) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sends mail" do
      expect { call }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    context "with email failure" do
      before do
        allow_any_instance_of(ApiEngineBase::EmailVerificationMailer).to receive(:verify_email).and_raise(StandardError, "This is an Error")
      end

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets message" do
        expect(call.msg).to eq("Unable to send email. Please try again later")
      end

      it "sets status" do
        expect(call.status).to eq(500)
      end
    end
  end
end
