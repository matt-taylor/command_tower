# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::PlainText::LoginWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(input: input) }

    let(:password) { "password1234" }

    context "with valid credentials" do
      let(:user) { create(:user, password: password, email: "wf-login@example.com", username: "wflogin") }
      let(:input) do
        CommandTower::Deserializers::Auth::PlainText::LoginDeserializer::Input.new(
          identifier: user.email,
          password: password
        )
      end

      before { user }

      it "returns success with login payload" do
        expect(result).to be_success
        expect(result.http_status).to eq(:created)
        expect(result.payload[:user][:email]).to eq(user.email)
        expect(result.payload[:token]).to be_present
        expect(result.payload[:tokenExpiresAt]).to be_present
        expect(result.response_effects[:set_token][:token]).to be_present
      end

      it "persists session_created as self_service" do
        expect { result }.to change { CommandTower::Audit::Event.where(action: "session_created").count }.by(1)
      end

      context "when inspecting the session_created row" do
        before { result }

        let(:row) { CommandTower::Audit::Event.find_by!(action: "session_created") }

        it "records self_service attribution" do
          expect(row.attribution_mode).to eq("self_service")
          expect(row.actor_user_id).to eq(user.id)
          expect(row.affected_user_id).to eq(user.id)
        end
      end

      context "when session_created is disabled" do
        before { CommandTower.config.registry.audit.set_enabled!(:session_created, false) }

        it "does not persist session_created" do
          expect { result }.not_to change { CommandTower::Audit::Event.where(action: "session_created").count }
        end
      end

      context "when asserting service delegation" do
        let(:service_result) do
          instance_double(
            CommandTower::Services::ServiceResult,
            success?: true,
            failure?: false,
            data: {
              user: user,
              token: "jwt-token",
              expires_at: "2026-07-14 04:46:14 +0000"
            },
            errors: []
          )
        end

        before do
          allow(CommandTower::Services::Auth::PlainText::Login).to receive(:call).and_return(service_result)
        end

        it "delegates to the login service" do
          described_class.call(input: input)
          expect(CommandTower::Services::Auth::PlainText::Login).to have_received(:call).with(
            identifier: user.email,
            password: password
          )
        end
      end
    end

    context "with invalid credentials" do
      let(:user) { create(:user, password: password, email: "wf-bad@example.com", username: "wfbad") }
      let(:input) do
        CommandTower::Deserializers::Auth::PlainText::LoginDeserializer::Input.new(
          identifier: user.email,
          password: "wrong-password"
        )
      end

      before { user }

      it "returns 401 invalid_credentials" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::InvalidCredentialsError)
        )
      end

      it "does not persist login_failed by default" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "login_failed").count }
      end
    end
  end
end
