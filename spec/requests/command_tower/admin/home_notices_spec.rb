# frozen_string_literal: true

RSpec.describe "PATCH /admin/home-notices/:key", :aggregate_failures, :with_rbac_setup, type: :request do
  include HomeNoticeSelectSpecHelpers

  let(:key) { "test.picks" }
  let(:path) { "/admin/home-notices/#{key}" }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    CommandTower::HomeNotices::Catalog.load!([campaign("test.picks")])
    # Hosts compose the grant into a role of their own; the platform ships none.
    CommandTower::Authorization::Role.create_role(
      name: "notice_operator", description: "Example host role with the kill-switch grant",
      entities: [CommandTower::Authorization::Entity.entities.fetch("admin_home_notices_kill")]
    )
  end

  it "rejects unauthenticated requests" do
    patch path, params: { enabled: false }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  context "without the grant" do
    let(:headers) { authenticate_request_with_bearer!(create(:user, :role_admin)) }

    before { patch path, params: { enabled: false }, as: :json, headers: headers }

    it "requires the admin_home_notices_kill grant" do
      expect(response).to have_http_status(:forbidden)
      expect(CommandTower::HomeNoticeControl.find_by(key:)).to be_nil
    end
  end

  context "with the grant" do
    let(:headers) { authenticate_request_with_bearer!(create(:user, roles: ["notice_operator"])) }

    it "switches the key off, not cached" do
      patch path, params: { enabled: false }, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.parsed_body.fetch("data")).to eq("key" => key, "enabled" => false)
      expect(CommandTower::HomeNoticeControl.find(key).enabled).to be(false)
    end

    it "audits the change once" do
      patch path, params: { enabled: false }, as: :json, headers: headers

      expect(CommandTower::Audit::Event.where(action: "home_notice_control_changed").count).to eq(1)
    end

    it "switches it back on" do
      patch path, params: { enabled: false }, as: :json, headers: headers
      patch path, params: { enabled: true }, as: :json, headers: headers

      expect(response.parsed_body.fetch("data")).to eq("key" => key, "enabled" => true)
    end

    it "returns 404 for an unknown key" do
      patch "/admin/home-notices/no.such_key", params: { enabled: false }, as: :json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for a non-boolean enabled" do
      patch path, params: { enabled: "no" }, as: :json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when enabled is missing" do
      patch path, params: {}, as: :json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context "when impersonating" do
    let(:operator) { create(:user, :role_owner) }
    let(:session) { create(:impersonation_session, actor: operator, target: create(:user, roles: ["notice_operator"])) }

    let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }

    it "is refused with 418 and writes nothing" do
      patch path, params: { enabled: false }, as: :json, headers: headers

      expect(response).to have_http_status(418)
      expect(response_error_code).to eq("admin_unavailable_during_impersonation")
      expect(CommandTower::HomeNoticeControl.find_by(key:)).to be_nil
    end
  end
end
