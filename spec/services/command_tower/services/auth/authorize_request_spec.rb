# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::AuthorizeRequest, :with_rbac_setup do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: current_user,
        controller_class: controller_class,
        action_name: action_name
      )
    end

    let(:controller_class) { CommandTower::Auth::EmailVerification::SendController }
    let(:action_name) { "create" }

    context "with a role the host mapped onto the action" do
      let(:current_user) { create(:user, roles: ["member"]) }

      it { expect(result).to be_success }

      it "reports authorization was required" do
        expect(result.data[:authorization_required]).to be(true)
      end
    end

    context "without the required role" do
      let(:current_user) { create(:user, roles: []) }

      it "returns ForbiddenError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ForbiddenError))
      end

      it "does not leak the underlying authorization message" do
        expect(result.errors.first.message).to eq("Forbidden")
      end
    end

    context "with an action the host never mapped" do
      let(:current_user) { create(:user, roles: ["member"]) }
      let(:controller_class) { CommandTower::Auth::LogoutController }

      it "fails closed with ForbiddenError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ForbiddenError))
      end
    end
  end
end
