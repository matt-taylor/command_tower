# frozen_string_literal: true

RSpec.describe "Me inbox X-UI-Catalog header", :messaging_inbox, :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:catalog_header) { "2" }

  before do
    create_inbox_for(user:)
    allow(CommandTower).to receive(:with_execution).and_call_original
  end

  context "when comparing bodies with and without the header" do
    let(:baseline_body) do
      get "/me/inbox", headers: headers
      response.body
    end

    before do
      baseline_body
      get "/me/inbox", headers: headers.merge("X-UI-Catalog" => catalog_header)
    end

    it { expect(response.body).to eq(baseline_body) }
  end

  context "when the header is 2" do
    before { get "/me/inbox", headers: headers.merge("X-UI-Catalog" => "2") }

    it "parses it into the execution context" do
      expect(CommandTower).to have_received(:with_execution).with(hash_including(ui_catalog: 2)).at_least(:once)
    end
  end

  context "when the header is garbage" do
    before { get "/me/inbox", headers: headers.merge("X-UI-Catalog" => "bogus") }

    it "falls back to 1" do
      expect(CommandTower).to have_received(:with_execution).with(hash_including(ui_catalog: 1)).at_least(:once)
    end
  end
end
