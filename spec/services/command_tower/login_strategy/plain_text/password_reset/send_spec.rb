# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::PasswordReset::Send do
  let(:email) { Faker::Internet.email }
  let(:user) { create(:user, email: email) }

  describe ".call" do
    subject(:call) { described_class.(email:) }

    context "with existing user" do
      before { user }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets message" do
        expect(call.message).to eq("If an account exists with that email, a password reset link has been sent.")
      end

      it "sends mail" do
        expect { call }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "creates user secret" do
        expect { call }.to change { UserSecret.where(reason: CommandTower::Secrets::PASSWORD_RESET).count }.by(1)
      end

      it "cleanses old tokens" do
        # Create an old token
        old_token = CommandTower::Secrets::Generate.(
          user: user,
          secret_length: 32,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          use_count_max: 1,
          death_time: 1.hour,
          type: CommandTower::Secrets::ALPHANUMERIC,
          cleanse: false
        ).secret

        # Request new token (should cleanse old one)
        call

        # Old token should be gone
        expect(UserSecret.find_by(secret: old_token)).to be_nil
      end

      context "with email failure" do
        before do
          allow_any_instance_of(CommandTower::PasswordResetMailer).to receive(:reset_password).and_raise(StandardError, "SMTP Error")
        end

        it "still succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets message" do
          expect(call.message).to eq("If an account exists with that email, a password reset link has been sent.")
        end

        it "does not send mail" do
          expect { call }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end

      context "with token generation failure" do
        before do
          allow(CommandTower::Secrets::Generate).to receive(:call).and_return(
            double(success?: false, failure?: true, msg: "Generation failed")
          )
        end

        it "still succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets message" do
          expect(call.message).to eq("If an account exists with that email, a password reset link has been sent.")
        end
      end

      context "with reset_password_path config" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset).to receive(:reset_password_path).and_return("/custom-reset-path")
          allow(CommandTower.config.app).to receive(:composed_url).and_return("https://example.com")
        end

        it "uses reset_password_path in email template" do
          call
          mail = ActionMailer::Base.deliveries.last
          expect(mail.body.to_s).to include("/custom-reset-path")
        end
      end

      context "with require_email: false" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
        end

        it "email link does not include email parameter" do
          call
          mail = ActionMailer::Base.deliveries.last
          token = UserSecret.where(reason: CommandTower::Secrets::PASSWORD_RESET).last.secret
          # Check that URL contains token but not email parameter
          expect(mail.body.to_s).to include("token=#{token}")
          expect(mail.body.to_s).not_to include("&email=")
        end
      end

      context "with require_email: true" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
        end

        it "email link includes email parameter" do
          call
          mail = ActionMailer::Base.deliveries.last
          token = UserSecret.where(reason: CommandTower::Secrets::PASSWORD_RESET).last.secret
          body = mail.body.to_s
          # Check that URL contains both token and email parameter (HTML encoded as &amp;email=)
          expect(body).to include("token=#{token}")
          expect(body).to match(/&amp;email=|&email=/)
          expect(body).to include(CGI.escape(email))
        end
      end
    end

    context "with non-existent user" do
      let(:email) { "nonexistent@example.com" }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets message" do
        expect(call.message).to eq("If an account exists with that email, a password reset link has been sent.")
      end

      it "does not send mail" do
        expect { call }.not_to change { ActionMailer::Base.deliveries.count }
      end

      it "does not create user secret" do
        expect { call }.not_to change { UserSecret.count }
      end
    end

    context "with invalid email" do
      let(:email) { "not-an-email" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end
    end

    context "with missing email" do
      let(:email) { nil }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end
    end
  end
end
