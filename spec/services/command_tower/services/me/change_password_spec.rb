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

    context "when persisting the audit fact" do
      before do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          described_class.call(
            user:,
            current_password:,
            password:,
            password_confirmation:
          )
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "password_changed") }

      it "persists password_changed without secrets" do
        expect(row.change_set).to eq({})
        expect(row.metadata).to eq("mechanism" => "authenticated_change")
        expect(row.attribution_mode).to eq("self_service")
        expect(row.change_set.to_s).not_to include(password)
        expect(row.metadata.to_s).not_to include(password)
        expect(row.metadata.to_s).not_to include(stored_password)
      end
    end

    context "when the user has open impersonation sessions" do
      let!(:open_session) { create(:impersonation_session, actor: user, target: create(:user)) }

      before do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) { result }
      end

      it "ends those sessions as revoked" do
        expect(open_session.reload.end_reason).to eq("revoked")
      end
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
