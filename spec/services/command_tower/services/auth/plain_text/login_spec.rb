# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PlainText::Login do
  describe ".call" do
    subject(:result) { described_class.call(identifier: identifier, password: password) }

    let(:password) { "password1234" }
    let(:user) { create(:user, password: password, email: "service-login@example.com", username: "svclogin") }
    let(:identifier) { user.email }

    before { user }

    context "with valid credentials" do
      it "returns a successful ServiceResult" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_success
      end

      it "returns user, token, and expires_at in data" do
        expect(result.data[:user]).to eq(user)
        expect(result.data[:token]).to be_present
        expect(result.data[:expires_at]).to be_present
      end

      it "records the successful login on the user" do
        expect { result }.to change { user.reload.successful_login }.by(1)
      end
    end

    context "with invalid credentials" do
      subject(:result) { described_class.call(identifier: identifier, password: attempt_password) }

      let(:attempt_password) { "wrong-password" }

      it "returns a failed ServiceResult" do
        expect(result).to be_failure
      end

      it "returns InvalidCredentialsError" do
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::InvalidCredentialsError)
        )
      end
    end
  end
end
