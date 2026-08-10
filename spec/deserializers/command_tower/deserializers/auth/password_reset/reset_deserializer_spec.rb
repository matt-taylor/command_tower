# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::PasswordReset::ResetDeserializer do
  describe ".call" do
    subject(:deserialized) { described_class.call(params) }

    context "with camelCase password confirmation" do
      let(:params) { { token: " abc123 ", password: "newpassword5678", passwordConfirmation: "newpassword5678" } }

      it { expect(deserialized).to be_success }
      it { expect(deserialized.input.token).to eq("abc123") }
      it { expect(deserialized.input.password_confirmation).to eq("newpassword5678") }
      it { expect(deserialized.input.email).to be_nil }
    end

    context "with snake_case password confirmation" do
      let(:params) { { token: "abc123", password: "newpassword5678", password_confirmation: "newpassword5678" } }

      it { expect(deserialized).to be_success }
      it { expect(deserialized.input.password_confirmation).to eq("newpassword5678") }
    end

    context "with an email" do
      let(:params) do
        { token: "abc123", password: "newpassword5678", passwordConfirmation: "newpassword5678", email: " A@B.com " }
      end

      it { expect(deserialized.input.email).to eq("a@b.com") }
    end

    context "with everything missing" do
      let(:params) { {} }

      it { expect(deserialized).to be_failure }

      it "names each missing field" do
        expect(deserialized.errors).to eq(
          [{
            token: "Token is required",
            password: "Password is required",
            passwordConfirmation: "Password confirmation is required"
          }]
        )
      end
    end
  end
end
