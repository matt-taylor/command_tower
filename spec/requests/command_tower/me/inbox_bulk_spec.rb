# frozen_string_literal: true

RSpec.describe "Me inbox bulk mutations", :with_rbac_setup, :messaging_inbox, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let!(:first) { create_inbox_for(user:) }
  let!(:second) { create_inbox_for(user:) }

  it "marks requested inbox items read" do
    post "/me/inbox/bulk/read", params: { ids: [first.id, second.id] }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to include("ids" => contain_exactly(first.id, second.id), "changedCount" => 2)
    expect([first, second].map(&:reload).map(&:viewed_at)).to all(be_present)
  end
end
