# frozen_string_literal: true

RSpec.describe "GET /me/home-notices route", :with_rbac_setup, type: :request do
  let(:owner) { create(:user, :role_owner) }

  around do |example|
    original = CommandTower.config.home_notices.enabled
    example.run
  ensure
    CommandTower.config.home_notices.enabled = original
  end

  context "when home notices are disabled" do
    before do
      CommandTower.config.home_notices.enabled = false
      get "/me/home-notices", headers: authenticate_request_with_bearer!(owner)
    end

    it { expect(response).to have_http_status(:not_found) }
  end

  context "when home notices are enabled" do
    before { CommandTower.config.home_notices.enabled = true }

    it "routes to Me::HomeNoticesController#index" do
      expect(CommandTower::Engine.routes.recognize_path("/me/home-notices")).to include(
        controller: "command_tower/me/home_notices", action: "index"
      )
    end
  end
end
