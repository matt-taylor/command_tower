# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordReset::Send do
  describe ".call" do
    subject(:result) { described_class.call(email: email) }

    let(:non_enumerating_message) { described_class::SENT_MESSAGE }

    before { ActionMailer::Base.deliveries.clear }

    context "with a known email" do
      let!(:user) { create(:user, email: "known-reset@example.com") }
      let(:email) { user.email }

      it { expect(result).to be_success }

      it "returns the non-enumerating message" do
        expect(result.data[:message]).to eq(non_enumerating_message)
      end

      it "delivers a reset email" do
        result

        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end

      it "issues a single-use reset token" do
        expect { result }
          .to change { UserSecret.where(user: user, reason: CommandTower::Secrets::PASSWORD_RESET).count }
          .by(1)
      end

      context "when cleansing previously issued tokens" do
        let!(:stale) do
          CommandTower::Secrets::Generate.(
            user: user,
            secret_length: 32,
            reason: CommandTower::Secrets::PASSWORD_RESET,
            use_count_max: 1,
            death_time: 1.hour,
            type: CommandTower::Secrets::ALPHANUMERIC,
            cleanse: false
          ).secret
        end

        before { result }

        it "removes the stale token" do
          expect(UserSecret.find_by(secret: stale)).to be_nil
        end
      end

      context "when the mailer raises" do
        before do
          allow(CommandTower::PasswordResetMailer)
            .to receive(:reset_password)
            .and_raise(StandardError, "SMTP Error")
        end

        it "still reports success so callers cannot enumerate accounts" do
          expect(result).to be_success
          expect(result.data[:message]).to eq(non_enumerating_message)
        end

        it "delivers nothing" do
          expect { result }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end

      context "when token generation is exhausted" do
        before do
          allow(CommandTower::Secrets::Generate).to receive(:call).and_return(
            CommandTower::Secrets::Generate::Issued.failure(msg: "Generation failed")
          )
        end

        it "still reports success so callers cannot enumerate accounts" do
          expect(result).to be_success
          expect(result.data[:message]).to eq(non_enumerating_message)
        end

        it "delivers nothing" do
          expect { result }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end

      context "with a configured reset path" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset)
            .to receive(:reset_password_path).and_return("/custom-reset-path")
          allow(CommandTower.config.app).to receive(:composed_url).and_return("https://example.com")
        end

        it "builds the emailed link from that path" do
          result

          expect(ActionMailer::Base.deliveries.last.body.to_s).to include("/custom-reset-path")
        end
      end

      context "with require_email disabled" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
        end

        it "omits the email from the emailed link" do
          result

          body = ActionMailer::Base.deliveries.last.body.to_s
          token = UserSecret.where(reason: CommandTower::Secrets::PASSWORD_RESET).last.secret
          expect(body).to include("token=#{token}")
          expect(body).not_to include("&email=")
        end
      end

      context "with require_email enabled" do
        before do
          allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
        end

        it "includes the email in the emailed link" do
          result

          body = ActionMailer::Base.deliveries.last.body.to_s
          token = UserSecret.where(reason: CommandTower::Secrets::PASSWORD_RESET).last.secret
          expect(body).to include("token=#{token}")
          expect(body).to match(/&amp;email=|&email=/)
          expect(body).to include(CGI.escape(email))
        end
      end
    end

    context "with an unknown email" do
      let(:email) { "nobody@example.com" }

      it "returns the same message so callers cannot enumerate accounts" do
        expect(result).to be_success
        expect(result.data[:message]).to eq(non_enumerating_message)
      end

      it "delivers nothing" do
        result

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "issues no token" do
        expect { result }.not_to change { UserSecret.count }
      end
    end

    context "with a malformed email" do
      let(:email) { "not-an-email" }

      it "returns a ValidationError naming the field" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(email: "Invalid email address")
      end
    end

    context "without an email" do
      let(:email) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end
  end
end
