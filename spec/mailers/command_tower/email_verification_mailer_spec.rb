# frozen_string_literal: true

RSpec.describe CommandTower::EmailVerificationMailer do
  include EnvHelpers

  let(:user) { build(:user, :unvalidated_email, first_name: "Ada", last_name: "Lovelace") }

  before { ActionMailer::Base.deliveries.clear }

  context "when SMTP username is absent" do
    before do
      CommandTower.config.credentials.smtp.user_name = ""
      CommandTower.config.credentials.smtp.password = ""
      with_env("GMAIL_USER_NAME" => nil, "GMAIL_PASSWORD" => nil) do
        described_class.verify_email("to@example.com", user, "123456").deliver_now
      end
    end

    it "falls back to from@example.com" do
      expect(ActionMailer::Base.deliveries.last.from).to eq(["from@example.com"])
    end
  end

  context "when delivering a verification code" do
    before { described_class.verify_email("to@example.com", user, "654321").deliver_now }

    it "includes the verification code in the HTML body" do
      expect(
        ActionMailer::Base.deliveries.last.html_part&.body&.to_s.presence ||
          ActionMailer::Base.deliveries.last.body.to_s
      ).to include("654321")
    end
  end

  context "when CredentialResolution SMTP username is available" do
    before do
      CommandTower.config.credentials.smtp.user_name = "from-cr@example.com"
      CommandTower.config.credentials.smtp.password = "secret"
      described_class.verify_email("to@example.com", user, "123456").deliver_now
    end

    it "uses CredentialResolution SMTP username for From when available" do
      expect(ActionMailer::Base.deliveries.last.from).to eq(["from-cr@example.com"])
    end
  end
end
