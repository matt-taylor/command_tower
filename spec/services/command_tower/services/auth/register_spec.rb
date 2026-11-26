# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::Register do
  describe ".call" do
    subject(:result) do
      described_class.call(
        first_name: first_name,
        last_name: last_name,
        username: username,
        email: email,
        password: password,
        password_confirmation: password_confirmation
      )
    end

    let(:first_name) { "Jane" }
    let(:last_name) { "Member" }
    let(:username) { "svcregister#{SecureRandom.hex(4)}" }
    let(:email) { "svc-register-#{SecureRandom.hex(4)}@example.com" }
    let(:password) { "correct-horse-9f3Qz!battery" }
    let(:password_confirmation) { password }

    it "returns the created user" do
      expect(result).to be_success
      expect(result.data[:user]).to be_a(User)
      expect(result.data[:user].email).to eq(email)
      expect(result.data[:user].username).to eq(username)
    end

    context "with a duplicate email" do
      let!(:existing_user) { create(:user, email: "svc-register-dup@example.com", username: "svcregisterdup") }
      let(:email) { "svc-register-dup@example.com" }

      it "returns EmailAlreadyRegisteredError with details" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::EmailAlreadyRegisteredError)
        expect(result.errors.first.details).to include(:email)
      end
    end

    context "with a duplicate username" do
      let!(:existing_user) { create(:user, email: "svc-register-other@example.com", username: "svcregistertaken") }
      let(:username) { "svcregistertaken" }

      it "returns a generic ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first).not_to be_a(CommandTower::Errors::Auth::EmailAlreadyRegisteredError)
      end
    end

    context "with mismatched password confirmation" do
      let(:password_confirmation) { "different-password" }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "when a required argument is missing" do
      let(:email) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end

    context "with only email and password" do
      let(:first_name) { nil }
      let(:last_name) { nil }
      let(:username) { nil }
      let(:password_confirmation) { nil }

      it "creates a user without a username" do
        expect(result).to be_success
        expect(result.data[:user].username).to be_nil
        expect(result.data[:user].first_name).to eq("")
      end
    end

    context "with a duplicate email and the friendly message" do
      let!(:existing_user) { create(:user, email: "svc-register-friendly@example.com", username: "svcfriendly") }
      let(:email) { "svc-register-friendly@example.com" }

      it "uses the friendly message" do
        expect(result.errors.first.details[:email]).to eq(described_class::EMAIL_TAKEN_MESSAGE)
      end
    end

    context "with a common password" do
      let(:password) { "password123" }
      let(:password_confirmation) { password }

      it "lists the failed rule ids beside the message" do
        expect(result).to be_failure
        expect(result.errors.first.details).to include(passwordRulesFailed: ["not_common"])
        expect(result.errors.first.details[:password]).to be_present
      end
    end
  end
end
