# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::RegisterWorkflow, :messaging_accept do
  describe ".call" do
    subject(:result) { described_class.call(input: input, client_ip: client_ip) }

    let(:client_ip) { "203.0.113.30" }
    let(:username) { "wfregister#{SecureRandom.hex(4)}" }
    let(:email) { "wf-register-#{SecureRandom.hex(4)}@example.com" }
    let(:input) do
      CommandTower::Deserializers::Auth::RegisterDeserializer::Input.new(
        first_name: "Jane",
        last_name: "Member",
        username: username,
        email: email,
        password: "password1234",
        password_confirmation: "password1234"
      )
    end

    before do
      flush_signup_rate_limits!
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: "user_welcome",
          allowed_channels: [],
          default_channels: [],
          inbox_available: true,
          user_configurable: false,
          mandatory: false,
          default_preference_state: { "channels" => {}, "inbox" => true },
        ),
      )
      allow(CommandTower.config.messaging).to receive(:welcome_content).and_return(
        -> {
          {
            notification_type_key: "user_welcome",
            title: "Welcome to DoubleFloor",
            body: "Welcome to DoubleFloor! Your account is ready.",
          }
        }
      )
      allow(CommandTower.config.messaging).to receive(:platform_enabled_channels).and_return(-> { [] })
    end

    it "returns the created user without exposing a token" do
      expect(result).to be_success
      expect(result.http_status).to eq(:created)
      expect(result.payload[:user]).to include(
        email: email,
        username: username,
        firstName: "Jane",
        lastName: "Member",
        emailValidated: false
      )
      expect(result.payload[:message]).to eq("Account created successfully")
      expect(result.payload).not_to have_key(:token)
    end

    context "when producing welcome inbox content" do
      let(:registered_user) { User.find_by!(email: email) }
      let(:communication) do
        CommandTower::Messaging::Communication.find_by!(
          user_id: registered_user.id,
          notification_type_key: "user_welcome",
          host_event_identity: "user_welcome/#{registered_user.id}",
        )
      end

      before { result }

      it "synchronously produces a welcome InboxItem before returning" do
        expect(result).to be_success
        expect(communication.inbox_item).to be_present
        expect(communication.title).to eq("Welcome to DoubleFloor")
      end
    end

    context "when welcome Produce fails" do
      before do
        allow(CommandTower::Services::Messaging::Communications::Produce).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::InternalError.new]
          )
        )
      end

      it "still creates the account" do
        expect(result).to be_success
        expect(result.http_status).to eq(:created)
        expect(User.find_by(email: email)).to be_present
      end
    end

    context "when welcome content is disabled" do
      before do
        allow(CommandTower.config.messaging).to receive(:welcome_content).and_return(-> { nil })
        allow(CommandTower::Services::Messaging::Communications::Produce).to receive(:call)
      end

      before { result }

      it "skips Produce" do
        expect(result).to be_success
        expect(CommandTower::Services::Messaging::Communications::Produce).not_to have_received(:call)
      end
    end

    context "with a duplicate email" do
      let!(:existing_user) { create(:user, email: "wf-register-dup@example.com", username: "wfregisterdup") }
      let(:email) { "wf-register-dup@example.com" }

      it "returns email_already_registered as unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::EmailAlreadyRegisteredError)
      end
    end

    context "when the ip is rate limited" do
      before do
        allow(CommandTower::Services::Auth::SignupRateLimits::CheckRegister).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::Auth::SignupIpRateLimitError.new]
          )
        )
        allow(CommandTower::Services::Auth::Register).to receive(:call)
        result
      end

      it "returns too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
      end

      it "does not attempt registration" do
        expect(CommandTower::Services::Auth::Register).not_to have_received(:call)
      end
    end
  end
end
