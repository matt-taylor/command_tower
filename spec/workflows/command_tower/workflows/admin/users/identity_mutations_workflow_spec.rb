# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Users::UpdateNameWorkflow do
  describe ".call" do
    let(:admin) { create(:user, :role_admin) }
    let(:member) { create(:user, roles: ["member"], first_name: "Jane", last_name: "Member") }

    context "when the update succeeds" do
      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
          described_class.call(
            id: member.id,
            user: admin,
            first_name: "Ada",
            last_name: "Lovelace"
          )
        end
      end

      it { expect(result).to be_success }

      it "serializes the Show user payload" do
        expect(result.payload.fetch(:firstName)).to eq("Ada")
        expect(result.payload.fetch(:lastName)).to eq("Lovelace")
        expect(result.payload).not_to have_key(:passwordDigest)
      end
    end

    context "when the user is missing" do
      subject(:result) { described_class.call(id: 0, user: admin, first_name: "Ada", last_name: "Lovelace") }

      it { expect(result).to be_failure }

      it { expect(result.http_status).to eq(:not_found) }
    end

    context "when audit is recorded" do
      before do
        CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
          described_class.call(
            id: member.id,
            user: admin,
            first_name: "Ada",
            last_name: "Lovelace"
          )
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "admin_user_name_changed") }

      it "persists admin_direct attribution against the target" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.actor_user_id).to eq(admin.id)
        expect(row.affected_user_id).to eq(member.id)
      end
    end
  end
end

RSpec.describe CommandTower::Workflows::Admin::Users::UpdateEmailWorkflow do
  describe ".call" do
    let(:admin) { create(:user, :role_admin) }
    let(:member) { create(:user, roles: ["member"], email: "old@example.com", email_validated: true) }

    context "when the email changes" do
      before do
        CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
          described_class.call(id: member.id, user: admin, email: "new@example.com")
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "admin_user_email_changed") }

      it "does not reuse email_verified" do
        expect(CommandTower::Audit::Event.where(action: "email_verified")).to be_empty
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.affected_user_id).to eq(member.id)
        expect(row.metadata).to eq("email_changed" => true)
      end
    end
  end
end

RSpec.describe CommandTower::Workflows::Admin::Users::SetEmailValidatedWorkflow do
  describe ".call" do
    let(:admin) { create(:user, :role_admin) }
    let(:member) { create(:user, :unvalidated_email, roles: ["member"]) }

    context "when validation is set" do
      before do
        CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
          described_class.call(id: member.id, user: admin, email_validated: true)
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "admin_user_email_validation_changed") }

      it "records the boolean change without email_verified" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.affected_user_id).to eq(member.id)
        expect(CommandTower::Audit::Event.where(action: "email_verified")).to be_empty
      end
    end
  end
end
