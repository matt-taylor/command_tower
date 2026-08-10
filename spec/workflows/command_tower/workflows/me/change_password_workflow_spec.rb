# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ChangePasswordWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        current_password: current_password,
        password: password,
        password_confirmation: password_confirmation
      )
    end

    let(:user) { create(:user) }
    let(:current_password) { "current-password" }
    let(:password) { "new-password1234" }
    let(:password_confirmation) { password }

    context "when the password change succeeds" do
      before do
        allow(CommandTower::Services::Me::ChangePassword).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.success
        )
      end

      it "returns the change password payload with clear token effect" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:message]).to eq("Password updated successfully.")
        expect(result.response_effects[:clear_token]).to eq(true)
      end
    end

    context "when the password change fails validation" do
      let(:validation_error) do
        CommandTower::Errors::ValidationError.new(details: { currentPassword: "Incorrect current password" })
      end

      before do
        allow(CommandTower::Services::Me::ChangePassword).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [validation_error])
        )
      end

      it "returns unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to eq(validation_error)
      end
    end
  end
end
