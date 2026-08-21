# frozen_string_literal: true

RSpec.describe "Impersonation product attribution", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator) }
  let(:target) { create(:user, roles: ["member"]) }
  let!(:session) { create(:impersonation_session, actor: operator, target:) }
  let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }

  before do
    allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(true)
    patch "/me/phone", headers: headers, params: { phoneNumber: "4155552671" }, as: :json
  end

  it { expect(response).to have_http_status(:ok) }

  it "records phone_updated as impersonation against the target" do
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").attribution_mode).to eq("impersonation")
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").actor_user_id).to eq(operator.id)
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").affected_user_id).to eq(target.id)
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").effective_user_id).to eq(target.id)
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").originating_administrator_id).to eq(operator.id)
    expect(CommandTower::Audit::Event.find_by!(action: "phone_updated").impersonation_active).to be(true)
  end
end
