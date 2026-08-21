# frozen_string_literal: true

RSpec.describe "Impersonation logout isolation", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator) }
  let(:target_a) { create(:user, roles: ["member"]) }
  let(:target_b) { create(:user, roles: ["member"]) }
  let!(:session_a) { create(:impersonation_session, actor: operator, target: target_a) }
  let!(:session_b) { create(:impersonation_session, actor: operator, target: target_b) }

  before do
    CommandTower.configure do |config|
      config.jwt.cookie.enabled = true
    end
    cookies[CommandTower.config.jwt.cookie.name] = impersonation_token_for(operator, session_a)
    post "/auth/logout", as: :json
  end

  after do
    CommandTower.configure do |config|
      config.jwt.cookie.enabled = false
    end
  end

  it { expect(response).to have_http_status(:ok) }

  it "ends only the overlay carried by the logged-out credential" do
    expect(session_a.reload.end_reason).to eq("logout")
    expect(session_b.reload.open?).to be(true)
  end
end
