# frozen_string_literal: true

RSpec.describe "One-click unsubscribe", :aggregate_failures, :messaging_unsubscribe, type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, roles: ["member"], email: "unsub-ct@example.com") }
  let(:token) { unsubscribe_token_for(user_id: user.id) }
  let(:limits) { CommandTower::Services::Messaging::Unsubscribe::CheckRateLimit }

  before do
    flush_signup_rate_limits!
    seed_unsubscribe_types!
  end

  shared_examples "a generic refusal" do
    let(:refusal) do
      { "code" => "validation_failed", "message" => "Validation failed", "details" => { "token" => "invalid" } }
    end

    it "answers the one refusal status, body and shape" do
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["data"]).to be_nil
      expect(response.parsed_body["errors"]).to eq([refusal])
    end

    it "changes nothing" do
      expect(unsubscribe_audit_rows.count).to eq(0)
      expect(email_permitted?(user)).to be(true)
    end
  end

  describe "POST with a valid token" do
    before { post_unsubscribe(token) }

    it "answers 200 and turns email off for that type" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("unsubscribed" => true)
      expect(email_permitted?(user)).to be(false)
    end

    it "audits once against the user and sets privacy headers" do
      expect(unsubscribe_audit_rows.pluck(:affected_user_id)).to eq([user.id])
      expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "does not emit a second audit on a repeat and still answers 200" do
      post_unsubscribe(token)
      expect(response).to have_http_status(:ok)
      expect(unsubscribe_audit_rows.count).to eq(1)
    end
  end

  describe "POST ignoring cookies" do
    before { post MessagingUnsubscribeHelper::ENDPOINT, params: { token: }, headers: { "Cookie" => "bogus=1" } }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "POST refusals" do
    context "with a tampered token" do
      before { post_unsubscribe("#{token}x") }

      it_behaves_like "a generic refusal"
    end

    context "with an expired token" do
      before do
        token
        travel_to(91.days.from_now) { post_unsubscribe(token) }
      end

      it_behaves_like "a generic refusal"
    end

    context "with a token signed for another purpose" do
      let(:other) do
        CommandTower::Messaging::Unsubscribe::TokenVerifier.verifier.generate(
          { u: user.id, t: "class_canceled" }, purpose: "other", expires_in: 1.day
        )
      end

      before { post_unsubscribe(other) }

      it_behaves_like "a generic refusal"
    end

    %w[password_changed no_such_type sms_only].each do |key|
      context "with a token for the #{key} type" do
        before { post_unsubscribe(unsubscribe_token_for(user_id: user.id, key:)) }

        it_behaves_like "a generic refusal"
      end
    end

    context "with a token for an unknown user" do
      before { post_unsubscribe(unsubscribe_token_for(user_id: user.id + 10_000)) }

      it_behaves_like "a generic refusal"
    end

    context "with garbage" do
      before { post_unsubscribe("garbage") }

      it_behaves_like "a generic refusal"
    end
  end

  describe "GET" do
    let!(:invalid_location) do
      get MessagingUnsubscribeHelper::ENDPOINT, params: { token: "garbage" }
      response.headers["Location"]
    end

    before { get MessagingUnsubscribeHelper::ENDPOINT, params: { token: } }

    it "redirects 303 to the preferences page without mutating or auditing" do
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to start_with(CommandTower.config.application.composed_url.to_s)
      expect(unsubscribe_audit_rows.count).to eq(0)
      expect(email_permitted?(user)).to be(true)
    end

    it "leaks neither the token nor the user id and sets privacy headers" do
      expect(response.headers["Location"]).not_to include(token, "token")
      expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "redirects the same way for an invalid token" do
      expect(response.headers["Location"]).to eq(invalid_location)
    end
  end

  describe "rate limits" do
    context "when one token is replayed past its limit" do
      before { (limits::TOKEN_LIMIT + 1).times { post_unsubscribe(token) } }

      it "answers 429 with unsubscribe_rate_limited" do
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body["errors"].first["code"]).to eq("unsubscribe_rate_limited")
      end
    end

    context "when one token is at its limit" do
      before { limits::TOKEN_LIMIT.times { post_unsubscribe(token) } }

      it "still answers 200 and keeps a separate budget per token" do
        expect(response).to have_http_status(:ok)
        post_unsubscribe(unsubscribe_token_for(user_id: user.id, key: "sms_only"))
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when one client ip sends many distinct tokens" do
      before { (limits::IP_LIMIT + 1).times { |i| post_unsubscribe("junk-#{i}") } }

      it "answers 429 only far above the token limit" do
        expect(limits::IP_LIMIT).to be > limits::TOKEN_LIMIT * 5
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context "when Redis is down" do
      before do
        allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::BaseError)
        post_unsubscribe(token)
      end

      it "fails open" do
        expect(response).to have_http_status(:ok)
        expect(email_permitted?(user)).to be(false)
      end
    end
  end

  describe "log filtering" do
    let(:log) { StringIO.new }
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    before do
      allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log))
      allow(ActionController::Base).to receive(:logger).and_return(ActiveSupport::Logger.new(log))
      post_unsubscribe(token)
    end

    it "filters the token parameter and keeps it out of the request log" do
      expect(filter.filter("token" => "secret-token")).to eq("token" => "[FILTERED]")
      expect(log.string).not_to include(token)
    end
  end
end
