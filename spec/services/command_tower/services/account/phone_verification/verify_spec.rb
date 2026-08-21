# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::PhoneVerification::Verify do
  describe ".call" do
    let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: false) }

    before do
      CommandTower::Identity::PhoneVerification::SmsTransport.reset_adapter!
      CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter.reset!
      allow(CommandTower.config.identity.phone_verification).to receive(:sms_adapter).and_return("fake")
      allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(0.seconds)
    end

    let(:send_code!) do
      lambda do
        expect(CommandTower::Services::Account::PhoneVerification::Send.call(user:)).to be_success

        UserSecret.find_by!(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION).secret
      end
    end

    context "when verification succeeds" do
      let(:code) { send_code!.call }

      subject(:result) { described_class.call(user:, code:) }

      it "marks the phone validated on success" do
        expect(result).to be_success
        expect(result.data[:already_verified]).to eq(false)
        expect(user.reload.phone_number_validated).to eq(true)
      end

      context "when persisting the audit fact" do
        before do
          CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
            described_class.call(user:, code:)
          end
        end

        let(:row) { CommandTower::Audit::Event.find_by!(action: "phone_verified") }

        it "persists phone_verified" do
          expect(row.affected_user_id).to eq(user.id)
          expect(row.attribution_mode).to eq("self_service")
        end
      end

      it "clears outstanding challenges once verified" do
        result

        expect(UserSecret.where(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION)).to be_empty
      end
    end

    context "when already verified" do
      before { user.update!(phone_number_validated: true) }

      subject(:result) { described_class.call(user:, code: "000000") }

      it "is idempotent when already verified" do
        expect(result).to be_success
        expect(result.data[:already_verified]).to eq(true)
      end

      it "does not persist phone_verified" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "phone_verified").count }
      end
    end

    context "with a wrong code" do
      before { send_code!.call }

      subject(:result) { described_class.call(user:, code: "000000") }

      it "returns PhoneVerificationCodeInvalidError for a wrong code" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationCodeInvalidError)
      end
    end

    context "when the phone is replaced after sending" do
      let(:code) { send_code!.call }

      before do
        code
        CommandTower::Services::Account::UpdatePhone.call(user:, phone_number: "+14155552672")
      end

      subject(:result) { described_class.call(user: user.reload, code:) }

      it "returns PhoneVerificationStaleError after the phone is replaced" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationStaleError)
        expect(user.reload.phone_number_validated).to eq(false)
      end
    end

    context "with an expired code" do
      let(:code) { send_code!.call }

      before { UserSecret.find_by!(secret: code).update!(death_time: 1.hour.ago) }

      subject(:result) { described_class.call(user:, code:) }

      it "returns PhoneVerificationExpiredError for a dead code" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationExpiredError)
      end
    end

    context "when the user has no phone" do
      let(:user_without_phone) { create(:user, :without_phone) }

      subject(:result) { described_class.call(user: user_without_phone, code: "000000") }

      it "returns PhoneMissingError when the user has no phone" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneMissingError)
      end
    end

    context "when a code is resent for a replacement phone" do
      before do
        send_code!.call
        CommandTower::Services::Account::UpdatePhone.call(user:, phone_number: "+14155552672")
        user.reload
      end

      let(:new_code) { send_code!.call }

      before { new_code }

      it "binds a resent code to the replacement phone" do
        expect(UserSecret.find_by!(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION).extra)
          .to eq("+14155552672")
        expect(described_class.call(user:, code: new_code)).to be_success
        expect(user.reload.phone_number_validated).to eq(true)
      end
    end
  end
end
