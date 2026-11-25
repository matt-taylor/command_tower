# frozen_string_literal: true

RSpec.describe "GET /me/home-notices", :aggregate_failures, :with_rbac_setup, type: :request do
  include HomeNoticeSelectSpecHelpers

  let(:user) { create(:user, :role_owner) }
  let(:auth_headers) { authenticate_request_with_bearer!(user) }
  let(:request_headers) { auth_headers.merge("X-UI-Catalog" => "2") }
  let(:data) { response.parsed_body["data"] }
  let(:blocking) { data["blocking"] }

  around do |example|
    original = CommandTower.config.home_notices.enabled
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower.config.home_notices.enabled = original
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    CommandTower.config.home_notices.enabled = true
    CommandTower::HomeNotices::Catalog.load!(
      [campaign("test.terms", kind: :blocking, body: ->(builder) { builder.card { |card| card.text "Terms updated" } })]
    )
  end

  context "when home notices are disabled" do
    before do
      CommandTower.config.home_notices.enabled = false
      get "/me/home-notices", headers: request_headers
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  context "without the me_home_notices grant" do
    let(:user) { create(:user, roles: ["member"]) }

    before { get "/me/home-notices", headers: request_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "with a role that grants me_home_notices" do
    let(:user) { create(:user, roles: ["home_notices_reader"]) }

    before { get "/me/home-notices", headers: request_headers }

    it { expect(response).to have_http_status(:ok) }
  end

  context "with an unauthenticated request" do
    before { get "/me/home-notices" }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "when the owner requests at catalog 2" do
    before { get "/me/home-notices", headers: request_headers }

    it "returns the blocking notice, cacheable by no one" do
      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "returns the selection shape" do
      expect(data.keys).to contain_exactly("blocking", "dismissible", "readOnly")
      expect(data).to include("dismissible" => nil, "readOnly" => false)
    end

    it "returns the notice shape with its document" do
      expect(blocking).to include("id" => "campaign:test.terms", "key" => "test.terms", "severity" => "blocking")
      expect(blocking.keys).to contain_exactly("id", "key", "severity", "endsAt", "document")
      expect(blocking["document"]).to be_a(Hash)
    end
  end

  context "when the client is at catalog 1" do
    before { get "/me/home-notices", headers: auth_headers.merge("X-UI-Catalog" => "1") }

    it "returns both notices null" do
      expect(response).to have_http_status(:ok)
      expect(data).to include("blocking" => nil, "dismissible" => nil)
    end
  end

  context "when the owner sends no X-UI-Catalog header" do
    before { get "/me/home-notices", headers: auth_headers }

    it "treats the client as catalog 1" do
      expect(data).to include("blocking" => nil, "dismissible" => nil)
    end
  end

  context "when the session is an impersonation" do
    let(:auth_headers) do
      operator = create(:user, :role_impersonation_operator)
      authenticate_impersonation_with_bearer!(operator, create(:impersonation_session, actor: operator, target: user))
    end

    before { get "/me/home-notices", headers: request_headers }

    it "returns readOnly true" do
      expect(response).to have_http_status(:ok)
      expect(data["readOnly"]).to be(true)
    end
  end

  context "when the 31st call arrives within the minute" do
    before { 31.times { get "/me/home-notices", headers: request_headers } }

    it "answers 429 with retry_after" do
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("errors", 0, "details", "retry_after")).to be_a(Integer)
    end
  end

  context "when the 30th call arrives within the minute" do
    before { 30.times { get "/me/home-notices", headers: request_headers } }

    it { expect(response).to have_http_status(:ok) }
  end

  context "when the rate limiter is unavailable" do
    before do
      auth_headers
      allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::BaseError)
      get "/me/home-notices", headers: request_headers
    end

    it "fails open" do
      expect(response).to have_http_status(:ok)
      expect(blocking).to include("key" => "test.terms")
    end
  end
end
