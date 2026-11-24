# frozen_string_literal: true

RSpec.describe "X-Time-Zone header", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"], last_known_timezone: nil, last_known_timezone_update: nil) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:zone) { "America/New_York" }
  let(:writer) { CommandTower::Services::Users::RecordLastKnownTimeZone }

  context "when the zone is valid on an authenticated 2xx request" do
    before { get "/me", headers: headers.merge("X-Time-Zone" => zone) }

    it { expect(response).to have_http_status(:ok) }
    it { expect(user.reload.last_known_timezone).to eq(zone) }
    it { expect(user.reload.last_known_timezone_update).to be_present }
  end

  context "when the zone is not a TZInfo identifier" do
    before { get "/me", headers: headers.merge("X-Time-Zone" => "Not/AZone") }

    it { expect(response).to have_http_status(:ok) }
    it { expect(user.reload.last_known_timezone).to be_nil }
  end

  context "when the zone is longer than 64 characters" do
    before { get "/me", headers: headers.merge("X-Time-Zone" => "America/#{'a' * 70}") }

    it { expect(response).to have_http_status(:ok) }
    it { expect(user.reload.last_known_timezone).to be_nil }
  end

  context "when the header is absent" do
    before { get "/me", headers: headers }

    it { expect(user.reload.last_known_timezone).to be_nil }
  end

  context "when the last write is under an hour old" do
    before do
      user.update!(last_known_timezone: "Europe/London", last_known_timezone_update: 10.minutes.ago)
      get "/me", headers: headers.merge("X-Time-Zone" => zone)
    end

    it { expect(user.reload.last_known_timezone).to eq("Europe/London") }
  end

  context "when the last write is over an hour old and the zone changed" do
    before do
      user.update!(last_known_timezone: "Europe/London", last_known_timezone_update: 2.hours.ago)
      get "/me", headers: headers.merge("X-Time-Zone" => zone)
    end

    it { expect(user.reload.last_known_timezone).to eq(zone) }
  end

  context "when the zone is unchanged" do
    before do
      user.update!(last_known_timezone: zone, last_known_timezone_update: 2.hours.ago)
      get "/me", headers: headers.merge("X-Time-Zone" => zone)
    end

    it { expect(user.reload.last_known_timezone_update).to be < 1.hour.ago }
  end

  context "when the writer raises" do
    before do
      allow(writer).to receive(:call).and_raise(StandardError, "boom")
      get "/me", headers: headers.merge("X-Time-Zone" => zone)
    end

    it { expect(response).to have_http_status(:ok) }
  end

  context "when the request is unauthenticated" do
    before do
      allow(writer).to receive(:call)
      get "/me", headers: { "X-Time-Zone" => zone }
    end

    it { expect(response).to have_http_status(:unauthorized) }
    it { expect(writer).not_to have_received(:call) }
  end

  context "when the response is not 2xx" do
    before { get "/admin/users", headers: headers.merge("X-Time-Zone" => zone) }

    it { expect(response.status).to be >= 400 }
    it { expect(user.reload.last_known_timezone).to be_nil }
  end
end
