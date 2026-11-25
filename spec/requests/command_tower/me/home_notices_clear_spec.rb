# frozen_string_literal: true

RSpec.describe "POST /me/home-notices/:id/(acknowledge|dismiss)", :aggregate_failures, :with_rbac_setup,
               type: :request do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers

  let(:user) { create(:user, :role_owner) }
  let(:auth_headers) { authenticate_request_with_bearer!(user) }
  let(:kind) { :blocking }
  let(:acknowledge) do
    lambda do |id = "campaign:test.terms"|
      post "/me/home-notices/#{id}/acknowledge", headers: auth_headers.merge("X-UI-Catalog" => "2")
    end
  end
  let(:dismiss) do
    lambda do |id = "campaign:test.terms"|
      post "/me/home-notices/#{id}/dismiss", headers: auth_headers.merge("X-UI-Catalog" => "2")
    end
  end

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
    CommandTower::HomeNotices::Catalog.load!([campaign("test.terms", kind:)])
  end

  context "when home notices are disabled" do
    before do
      CommandTower.config.home_notices.enabled = false
      acknowledge.call
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  context "with an unauthenticated request" do
    before { post "/me/home-notices/campaign:test.terms/acknowledge" }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "without the me_home_notices grant" do
    let(:user) { create(:user, roles: ["member"]) }

    before { acknowledge.call }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when the owner acknowledges a blocking campaign" do
    before { acknowledge.call }

    it "acknowledges, audits once and answers recorded true" do
      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.parsed_body["data"]).to eq("recorded" => true)
      expect(campaign_rows("test.terms").sole.acknowledged_at).to be_present
      expect(acknowledgement_audits.count).to eq(1)
    end
  end

  context "when the acknowledgement is sent twice" do
    before do
      acknowledge.call
      acknowledge.call
    end

    it "is idempotent: recorded false and one audit" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("recorded" => false)
      expect(acknowledgement_audits.count).to eq(1)
    end
  end

  context "when the acknowledged row belongs to another user" do
    before { acknowledge.call(campaign_row(user: create(:user), key: "test.terms").public_id) }

    it { expect(response).to have_http_status(:not_found) }
  end

  context "when the id is malformed" do
    before { acknowledge.call("campaign:Bad_Key") }

    it { expect(response).to have_http_status(:not_found) }
  end

  context "when the notice is killed" do
    before do
      CommandTower::HomeNoticeControl.create!(key: "test.terms", enabled: false)
      acknowledge.call
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
      acknowledge.call
    end

    it "answers 503 home_notices_unavailable" do
      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("home_notices_unavailable")
    end
  end

  context "when the write fails" do
    before do
      auth_headers
      allow(CommandTower::Services::HomeNotices::Acknowledge).to receive(:call).and_raise(ActiveRecord::StatementInvalid)
      allow(CommandTower::Events).to receive(:publish).and_call_original
      acknowledge.call
    end

    it "answers 503 and logs ack_server_error" do
      expect(response).to have_http_status(:service_unavailable)
      expect(CommandTower::Events).to have_received(:publish).with(
        category: :home_notices, name: "ack_server_error",
        payload: { user_id: user.id, error_class: "ActiveRecord::StatementInvalid" }
      ).once
    end
  end

  context "when the session is an impersonation" do
    let(:auth_headers) do
      operator = create(:user, :role_impersonation_operator)
      authenticate_impersonation_with_bearer!(operator, create(:impersonation_session, actor: operator, target: user))
    end

    before { acknowledge.call }

    it "answers 403 and writes nothing" do
      expect(response).to have_http_status(:forbidden)
      expect(campaign_rows("test.terms").count).to eq(0)
      expect(acknowledgement_audits.count).to eq(0)
    end
  end

  context "when the mutation limit is shared with impressions" do
    before do
      auth_headers
      allow(CommandTower.config.home_notices).to receive(:mutation_rate_limit_per_minute).and_return(2)
      post "/me/home-notices/campaign:test.terms/impression", headers: auth_headers
      acknowledge.call
      acknowledge.call
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
      acknowledge.call
    end

    it { expect(response).to have_http_status(:ok) }
  end

  context "when the acknowledgement is recorded" do
    before do
      auth_headers
      allow(CommandTower::Events).to receive(:publish).and_call_original
      acknowledge.call
    end

    it "logs home_notices.acknowledged with ids only" do
      expect(CommandTower::Events).to have_received(:publish).with(
        category: :home_notices, name: "acknowledged",
        payload: hash_including(user_id: user.id, notice_key: "test.terms", recorded: true)
      ).once
    end
  end

  context "when a dismissible campaign is dismissed" do
    let(:kind) { :dismissible }

    before do
      auth_headers
      allow(CommandTower::Events).to receive(:publish).and_call_original
      dismiss.call
    end

    it "dismisses it and audits once" do
      expect(response).to have_http_status(:ok)
      expect(campaign_rows("test.terms").sole.dismissed_until).to be_present
      expect(dismissal_audits.count).to eq(1)
    end

    it "logs home_notices.dismissed" do
      expect(CommandTower::Events).to have_received(:publish).with(
        category: :home_notices, name: "dismissed",
        payload: hash_including(user_id: user.id, notice_key: "test.terms", recorded: true)
      ).once
    end
  end

  context "when a blocking notice is dismissed" do
    before { dismiss.call }

    it "answers 422 and writes nothing" do
      expect(response).to have_http_status(:unprocessable_content)
      expect(campaign_rows("test.terms").count).to eq(0)
      expect(dismissal_audits.count).to eq(0)
    end
  end

  context "when a dismissal is sent during an impersonation" do
    let(:kind) { :dismissible }
    let(:auth_headers) do
      operator = create(:user, :role_impersonation_operator)
      authenticate_impersonation_with_bearer!(operator, create(:impersonation_session, actor: operator, target: user))
    end

    before { dismiss.call }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when the dismissal controls cannot be read" do
    let(:kind) { :dismissible }

    before do
      auth_headers
      allow(CommandTower::HomeNoticeControl).to receive(:where).and_raise(ActiveRecord::StatementInvalid)
      dismiss.call
    end

    it { expect(response).to have_http_status(:service_unavailable) }
  end
end
