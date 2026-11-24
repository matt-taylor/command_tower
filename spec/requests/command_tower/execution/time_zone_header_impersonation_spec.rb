# frozen_string_literal: true

RSpec.describe "X-Time-Zone header when impersonating", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator, last_known_timezone: nil) }
  let(:target) { create(:user, roles: ["member"], last_known_timezone: nil) }
  let(:session) do
    create(
      :impersonation_session,
      actor: operator,
      target:,
      idle_expires_at: 2.minutes.from_now,
      absolute_expires_at: 1.hour.from_now
    )
  end

  before do
    headers = authenticate_impersonation_with_bearer!(operator, session)
    get "/profile", headers: headers.merge("X-Time-Zone" => "America/New_York")
  end

  it { expect(response).to have_http_status(:ok) }
  it { expect(target.reload.last_known_timezone).to be_nil }
  it { expect(operator.reload.last_known_timezone).to be_nil }
end
