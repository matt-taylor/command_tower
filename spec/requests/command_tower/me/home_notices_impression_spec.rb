# frozen_string_literal: true

RSpec.describe "POST /me/home-notices/:id/impression", :aggregate_failures, :with_rbac_setup, type: :request do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user, :role_owner) }
  let(:auth_headers) { authenticate_request_with_bearer!(user) }
  let(:request_headers) { auth_headers.merge("X-UI-Catalog" => "2") }
  let(:notice_id) { "campaign:test.terms" }
  let(:impress) { ->(id = notice_id) { post "/me/home-notices/#{id}/impression", headers: request_headers } }

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
    CommandTower::HomeNotices::Catalog.load!([campaign("test.terms", kind: :blocking)])
  end

  context "when home notices are disabled" do
    before do
      CommandTower.config.home_notices.enabled = false
      impress.call
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  context "with an unauthenticated request" do
    before { post "/me/home-notices/#{notice_id}/impression" }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "without the me_home_notices grant" do
    let(:user) { create(:user, roles: ["member"]) }

    before { impress.call }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "with a role that grants me_home_notices" do
    let(:user) { create(:user, roles: ["home_notices_reader"]) }

    before { impress.call }

    it { expect(response).to have_http_status(:ok) }
  end

  context "when the owner records a campaign impression" do
    before { impress.call }

    it "records it, audits it once and answers recorded true" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("recorded" => true)
      expect(campaign_rows("test.terms").sole.impression_count).to eq(1)
      expect(impression_audits.count).to eq(1)
    end
  end

  context "when the same impression is sent twice" do
    before do
      impress.call
      impress.call
    end

    it "is idempotent inside 60 seconds: one row, one audit, recorded false" do
      expect(response.parsed_body["data"]).to eq("recorded" => false)
      expect(campaign_rows("test.terms").sole.impression_count).to eq(1)
      expect(impression_audits.count).to eq(1)
    end
  end

  context "when the notice is named by its public id" do
    before do
      row = campaign_row(user:, key: "test.terms")
      impress.call(row.public_id)
    end

    it "records it" do
      expect(response.parsed_body["data"]).to eq("recorded" => true)
      expect(campaign_rows("test.terms").sole.impression_count).to eq(1)
    end
  end

  context "when the row belongs to another user" do
    before do
      row = campaign_row(user: create(:user), key: "test.terms")
      impress.call(row.public_id)
    end

    it "answers 404" do
      expect(response).to have_http_status(:not_found)
      expect(impression_audits.count).to eq(0)
    end
  end

  context "when the id is malformed" do
    before { impress.call("campaign:Bad_Key") }

    it { expect(response).to have_http_status(:not_found) }
  end

  context "when the campaign is unknown" do
    before { impress.call("campaign:test.unknown") }

    it { expect(response).to have_http_status(:not_found) }
  end

  context "when the notice is killed" do
    before do
      CommandTower::HomeNoticeControl.create!(key: "test.terms", enabled: false)
      impress.call
    end

    it "answers 404 and writes nothing" do
      expect(response).to have_http_status(:not_found)
      expect(campaign_rows("test.terms").count).to eq(0)
    end
  end

  context "when the controls cannot be read" do
    before do
      auth_headers
      allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::StatementInvalid)
      impress.call
    end

    it "answers 503 home_notices_unavailable" do
      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("home_notices_unavailable")
    end
  end

  context "when the session is an impersonation" do
    let(:auth_headers) do
      operator = create(:user, :role_impersonation_operator)
      authenticate_impersonation_with_bearer!(operator, create(:impersonation_session, actor: operator, target: user))
    end

    before { impress.call }

    it "answers recorded false and writes nothing" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("recorded" => false)
      expect(campaign_rows("test.terms").count).to eq(0)
      expect(impression_audits.count).to eq(0)
    end
  end

  context "when the mutation limit is exceeded within the minute" do
    before do
      auth_headers
      allow(CommandTower.config.home_notices).to receive(:mutation_rate_limit_per_minute).and_return(2)
      3.times { impress.call }
    end

    it "answers 429 with retry_after" do
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("errors", 0, "details", "retry_after")).to be_a(Integer)
    end
  end

  context "when the rate limiter is unavailable" do
    before do
      auth_headers
      allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::BaseError)
      impress.call
    end

    it "fails open" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("recorded" => true)
    end
  end

  context "when the impression is recorded" do
    before do
      auth_headers
      allow(CommandTower::Events).to receive(:publish).and_call_original
      impress.call
    end

    it "logs home_notices.impression with ids only" do
      expect(CommandTower::Events).to have_received(:publish).with(
        category: :home_notices, name: "impression",
        payload: hash_including(user_id: user.id, notice_key: "test.terms", recorded: true)
      ).once
    end
  end
end
