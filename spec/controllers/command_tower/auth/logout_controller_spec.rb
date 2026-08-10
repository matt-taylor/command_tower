# frozen_string_literal: true

RSpec.describe CommandTower::Auth::LogoutController, type: :controller do
  routes { CommandTower::Engine.routes }

  describe "#create" do
    subject(:make_request) { post :create }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns logged_out" do
      expect(response.parsed_body["data"]).to eq("message" => "logged_out")
    end
  end
end
