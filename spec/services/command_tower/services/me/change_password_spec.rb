# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::ChangePassword do
  describe ".call" do
    subject(:result) do
      described_class.call(
        user:,
        current_password:,
        password:,
        password_confirmation:
      )
    end

    let(:stored_password) { "password1234abcdef" }
    let(:user) { create(:user, password: stored_password, password_confirmation: stored_password) }
    let(:current_password) { stored_password }
    let(:password) { "newpassword5678ghij" }
    let(:password_confirmation) { password }

    it "changes the password" do
      expect(result).to be_success
      expect(user.reload.authenticate(password)).to be_truthy
    end

    context "with an incorrect current password" do
      let(:current_password) { "wrong-password-xyz" }

      it "fails with a camelCase field error" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to have_key(:currentPassword)
      end
    end
  end
end
