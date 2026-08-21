# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::AuthenticateSession do
  describe ".call" do
    subject(:result) { described_class.call(request_context: request_context) }

    let(:jwt_cookie_name) { CommandTower.config.jwt.cookie.name }

    context "with a valid Bearer token" do
      let!(:user) { create(:user) }
      let(:request_context) do
        auth_request_context(headers: { authorization: "Bearer #{login_token_for(user)}" })
      end

      it "returns a successful ServiceResult" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_success
      end

      it "returns user and token_expires_at in data" do
        expect(result.data[:user]).to eq(user)
        expect(result.data[:token_expires_at]).to be_present
      end

      it "reports bearer token observations in metadata" do
        expect(result.metadata).to include(
          token_source: :header,
          authentication_mechanism: :jwt,
          authentication_failed: false,
          cookie_authenticated: false
        )
      end

      it "does not commit the response" do
        expect(request_context.response.committed?).to be(false)
      end
    end

    context "with a valid impersonation overlay" do
      let(:actor) { create(:user) }
      let(:target) { create(:user) }
      let!(:session) { create(:impersonation_session, actor:, target:) }
      let(:request_context) do
        auth_request_context(headers: { authorization: "Bearer #{impersonation_token_for(actor, session)}" })
      end

      after { CommandTower::Current.reset }

      it "returns the target as the current user" do
        expect(result).to be_success
        expect(result.data[:user]).to eq(target)
        expect(result.data[:actor_user]).to eq(actor)
        expect(CommandTower::Current.impersonation_active).to be(true)
      end
    end

    context "with an expired impersonation overlay" do
      let(:actor) { create(:user) }
      let(:target) { create(:user) }
      let!(:session) do
        create(:impersonation_session, actor:, target:, idle_expires_at: 1.minute.ago, absolute_expires_at: 1.hour.from_now)
      end
      let(:request_context) do
        auth_request_context(headers: { authorization: "Bearer #{impersonation_token_for(actor, session)}" })
      end

      after { CommandTower::Current.reset }

      it "returns ImpersonationSessionExpiredError without cookie-clear metadata" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::ImpersonationSessionExpiredError)
        expect(result.metadata[:impersonation_session_expired]).to be(true)
        expect(result.metadata).not_to have_key(:clear_auth_cookie)
      end
    end

    context "without a token" do
      let(:request_context) { auth_request_context }

      it "returns UnauthorizedError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::UnauthorizedError))
      end

      it "reports authentication failure observations" do
        expect(result.metadata).to include(
          token_source: nil,
          authentication_mechanism: :jwt,
          authentication_failed: true,
          cookie_authenticated: false
        )
      end

      it "leaves transport decisions out of metadata" do
        expect(result.metadata).not_to have_key(:clear_auth_cookie)
      end
    end

    context "with an unparseable token" do
      let(:request_context) { auth_request_context(headers: { authorization: "Bearer invalid-token" }) }

      it "returns UnauthorizedError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::UnauthorizedError))
      end

      it { expect(result.metadata[:authentication_failed]).to be(true) }
    end

    context "with an unverified email" do
      let!(:user) { create(:user, :unvalidated_email) }
      let(:request_context) do
        auth_request_context(headers: { authorization: "Bearer #{login_token_for(user)}" })
      end

      it "returns EmailVerificationRequiredError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::EmailVerificationRequiredError)
        )
      end

      it { expect(result.metadata[:token_source]).to eq(:header) }
      it { expect(result.metadata[:email_verification_required]).to be(true) }
    end

    context "when the caller bypasses email validation" do
      subject(:result) do
        described_class.call(request_context: request_context, bypass_email_validation: true)
      end

      let!(:user) { create(:user, :unvalidated_email) }
      let(:request_context) do
        auth_request_context(headers: { authorization: "Bearer #{login_token_for(user)}" })
      end

      it "authenticates the unverified user" do
        expect(result).to be_success
        expect(result.data[:user]).to eq(user)
      end
    end

    context "with cookie authentication" do
      let!(:user) { create(:user) }

      before do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = true
        end
      end

      after do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = false
        end
      end

      context "on a GET request with an invalid token" do
        let(:request_context) do
          auth_request_context(path: "/auth/session", cookies: { jwt_cookie_name => "invalid-token" })
        end

        it "returns UnauthorizedError with cookie observations" do
          expect(result).to be_failure
          expect(result.errors.first).to be_a(CommandTower::Errors::UnauthorizedError)
          expect(result.metadata).to include(
            token_source: :cookie,
            cookie_authenticated: true,
            authentication_failed: true
          )
        end
      end

      context "on a mutating request without CSRF" do
        let(:request_context) do
          auth_request_context(
            path: "/auth/logout",
            method: "POST",
            cookies: { jwt_cookie_name => login_token_for(user) }
          )
        end

        before do
          CommandTower.configure do |config|
            config.jwt.cookie.csrf.enabled = true
          end
        end

        after do
          CommandTower.configure do |config|
            config.jwt.cookie.csrf.enabled = false
          end
        end

        it "returns CsrfMissingError" do
          expect(result).to be_failure
          expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::Auth::CsrfMissingError))
        end

        it "reports cookie authentication observations" do
          expect(result.metadata).to include(
            token_source: :cookie,
            authentication_mechanism: :jwt,
            cookie_authenticated: true,
            authentication_failed: true
          )
        end
      end
    end
  end
end
