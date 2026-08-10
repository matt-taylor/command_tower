# frozen_string_literal: true

RSpec.describe CommandTower::CredentialResolution do
  around do |example|
    previous_resolver = CommandTower.credential_resolver
    reset_credentials!
    example.run
  ensure
    reset_credentials!
    CommandTower.credential_resolver = previous_resolver
  end

  describe ".resolve" do
    context "when the provider is unknown" do
      subject(:invoke) { described_class.resolve(:unknown) }

      it "raises ArgumentError for unknown provider" do
        expect { invoke }.to raise_error(ArgumentError, /Unknown credential provider/)
      end
    end

    context "twilio" do
      context "when resolving from ENV only" do
        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "ACenv", "TWILIO_AUTH_TOKEN" => "env-token") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "resolves from ENV when nothing else is set" do
          expect(creds).to be_a(described_class::TwilioCredentials)
          expect(creds.available?).to eq(true)
          expect(creds.account_sid).to eq("ACenv")
          expect(creds.auth_token).to eq("env-token")
        end
      end

      context "when ENV values contain whitespace" do
        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "  ACenv  ", "TWILIO_AUTH_TOKEN" => "  env-token  ") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "strips whitespace from ENV values" do
          expect(creds.account_sid).to eq("ACenv")
          expect(creds.auth_token).to eq("env-token")
        end
      end

      context "when ENV is missing" do
        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => nil, "TWILIO_AUTH_TOKEN" => nil) { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "returns unavailable blank credentials when ENV is missing" do
          expect(creds.available?).to eq(false)
          expect(creds.account_sid).to eq("")
          expect(creds.auth_token).to eq("")
        end
      end

      context "when config.credentials.twilio is set" do
        before do
          CommandTower.config.credentials.twilio.account_sid = "ACcfg"
          CommandTower.config.credentials.twilio.auth_token = "cfg-token"
        end

        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "ACenv", "TWILIO_AUTH_TOKEN" => "env-token") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "prefers config.credentials.twilio over ENV" do
          expect(creds.account_sid).to eq("ACcfg")
          expect(creds.auth_token).to eq("cfg-token")
        end
      end

      context "when config.credentials.twilio is partial" do
        before do
          CommandTower.config.credentials.twilio.account_sid = "ACpartial"
          CommandTower.config.credentials.twilio.auth_token = ""
        end

        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "ACenv", "TWILIO_AUTH_TOKEN" => "env-token") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "falls through to ENV when config.credentials.twilio is partial" do
          expect(creds.account_sid).to eq("ACenv")
          expect(creds.auth_token).to eq("env-token")
        end
      end

      context "when a custom resolver supplies credentials" do
        let(:resolver) do
          Object.new.tap do |object|
            object.define_singleton_method(:resolve) do |provider|
              raise "unexpected" unless provider == :twilio

              CommandTower::CredentialResolution::TwilioCredentials.new(
                account_sid: "ACcustom",
                auth_token: "custom-token",
              )
            end
          end
        end

        before { CommandTower.credential_resolver = resolver }

        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "ACenv", "TWILIO_AUTH_TOKEN" => "env-token") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "uses custom resolver when explicit credentials are unavailable" do
          expect(creds.account_sid).to eq("ACcustom")
          expect(creds.auth_token).to eq("custom-token")
        end
      end

      context "when a custom resolver returns unavailable credentials" do
        let(:resolver) do
          Object.new.tap do |object|
            object.define_singleton_method(:resolve) do |_provider|
              CommandTower::CredentialResolution::TwilioCredentials.new(account_sid: "", auth_token: "")
            end
          end
        end

        before { CommandTower.credential_resolver = resolver }

        around do |example|
          with_env("TWILIO_ACCOUNT_SID" => "ACenv", "TWILIO_AUTH_TOKEN" => "env-token") { example.run }
        end

        subject(:creds) { described_class.resolve(:twilio) }

        it "falls through to ENV when custom resolver returns unavailable" do
          expect(creds.account_sid).to eq("ACenv")
        end
      end

      context "when a custom resolver raises" do
        let(:resolver) do
          Object.new.tap do |object|
            object.define_singleton_method(:resolve) do |_provider|
              raise "vault down"
            end
          end
        end

        before { CommandTower.credential_resolver = resolver }

        subject(:invoke) { described_class.resolve(:twilio) }

        it "propagates custom resolver errors" do
          expect { invoke }.to raise_error(RuntimeError, "vault down")
        end
      end

      context "when a custom resolver returns the wrong type" do
        let(:resolver) do
          Object.new.tap do |object|
            object.define_singleton_method(:resolve) do |_provider|
              CommandTower::CredentialResolution::SmtpCredentials.new(user_name: "a", password: "b")
            end
          end
        end

        before { CommandTower.credential_resolver = resolver }

        subject(:invoke) { described_class.resolve(:twilio) }

        it "raises TypeError when custom resolver returns wrong type" do
          expect { invoke }.to raise_error(TypeError, /TwilioCredentials/)
        end
      end

      context "when inspecting TwilioCredentials" do
        let(:creds) do
          described_class::TwilioCredentials.new(account_sid: "ACsecret", auth_token: "tokensecret")
        end

        subject(:dump) { creds.inspect }

        it "redacts secrets in inspect" do
          expect(dump).to include("[REDACTED]")
          expect(dump).not_to include("ACsecret")
          expect(dump).not_to include("tokensecret")
        end
      end
    end

    context "smtp" do
      context "when resolving from ENV only" do
        around do |example|
          with_env("GMAIL_USER_NAME" => "user@example.com", "GMAIL_PASSWORD" => "app-pass") { example.run }
        end

        subject(:creds) { described_class.resolve(:smtp) }

        it "resolves from ENV when nothing else is set" do
          expect(creds).to be_a(described_class::SmtpCredentials)
          expect(creds.available?).to eq(true)
          expect(creds.user_name).to eq("user@example.com")
          expect(creds.password).to eq("app-pass")
        end
      end

      context "when config.credentials.smtp is set" do
        before do
          CommandTower.config.credentials.smtp.user_name = "cred@example.com"
          CommandTower.config.credentials.smtp.password = "cred-pass"
        end

        around do |example|
          with_env("GMAIL_USER_NAME" => "env@example.com", "GMAIL_PASSWORD" => "env-pass") { example.run }
        end

        subject(:creds) { described_class.resolve(:smtp) }

        it "prefers config.credentials.smtp over ENV" do
          expect(creds.user_name).to eq("cred@example.com")
          expect(creds.password).to eq("cred-pass")
        end
      end

      context "when config.credentials.smtp is partial" do
        before do
          CommandTower.config.credentials.smtp.user_name = "partial@example.com"
          CommandTower.config.credentials.smtp.password = ""
        end

        around do |example|
          with_env("GMAIL_USER_NAME" => "env@example.com", "GMAIL_PASSWORD" => "env-pass") { example.run }
        end

        subject(:creds) { described_class.resolve(:smtp) }

        it "falls through to ENV when config.credentials.smtp is partial" do
          expect(creds.user_name).to eq("env@example.com")
          expect(creds.password).to eq("env-pass")
        end
      end

      context "when a custom resolver supplies SMTP credentials" do
        let(:resolver) do
          Object.new.tap do |object|
            object.define_singleton_method(:resolve) do |provider|
              raise "unexpected" unless provider == :smtp

              CommandTower::CredentialResolution::SmtpCredentials.new(
                user_name: "custom@example.com",
                password: "custom-pass",
              )
            end
          end
        end

        before { CommandTower.credential_resolver = resolver }

        around do |example|
          with_env("GMAIL_USER_NAME" => "env@example.com", "GMAIL_PASSWORD" => "env-pass") { example.run }
        end

        subject(:creds) { described_class.resolve(:smtp) }

        it "uses custom resolver when explicit SMTP credentials are unavailable" do
          expect(creds.user_name).to eq("custom@example.com")
          expect(creds.password).to eq("custom-pass")
        end
      end

      context "when config.email must not supply credentials" do
        around do |example|
          with_env("GMAIL_USER_NAME" => "env@example.com", "GMAIL_PASSWORD" => "env-pass") { example.run }
        end

        subject(:creds) { described_class.resolve(:smtp) }

        it "does not read credentials from config.email" do
          expect(CommandTower.config.email).not_to respond_to(:user_name)
          expect(CommandTower.config.email).not_to respond_to(:password)
          expect(creds.user_name).to eq("env@example.com")
        end
      end

      context "when inspecting SmtpCredentials" do
        let(:creds) do
          described_class::SmtpCredentials.new(user_name: "u@example.com", password: "secret")
        end

        subject(:dump) { creds.inspect }

        it "redacts secrets in inspect" do
          expect(dump).not_to include("u@example.com")
          expect(dump).not_to include("secret")
        end
      end
    end
  end

  describe CommandTower::CredentialResolution::SmtpActionMailerBridge do
    around do |example|
      previous = Rails.configuration.action_mailer.smtp_settings.dup
      example.run
    ensure
      Rails.configuration.action_mailer.smtp_settings = previous
    end

    before do
      CommandTower.config.credentials.smtp.user_name = "bridge@example.com"
      CommandTower.config.credentials.smtp.password = "bridge-pass"
      described_class.apply!
    end

    subject(:settings) { Rails.configuration.action_mailer.smtp_settings }

    it "applies resolved SMTP credentials into action_mailer.smtp_settings" do
      expect(settings[:user_name]).to eq("bridge@example.com")
      expect(settings[:password]).to eq("bridge-pass")
    end
  end
end
