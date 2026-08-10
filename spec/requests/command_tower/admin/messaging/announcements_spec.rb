# frozen_string_literal: true

RSpec.describe "Admin messaging announcements", :with_rbac_setup, :messaging_accept, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:headers) { authenticate_request_with_bearer!(admin) }
  let!(:targets) { create_list(:user, 2) }

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "promotional_announcement",
        allowed_channels: %w[email sms],
        default_channels: %w[email sms],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      ),
    )
    allow(CommandTower.config.messaging).to receive(:platform_enabled_channels).and_return(-> { %w[email sms] })
    allow(CommandTower.config.messaging).to receive(:resolve_announcement_audience).and_return(
      lambda { |selection|
        selection = selection.with_indifferent_access
        case selection[:mode]&.to_sym
        when :user_ids then Array(selection[:ids]).map(&:to_i)
        when :all_users then User.pluck(:id)
        else []
        end
      }
    )
  end

  it "rejects unauthenticated requests" do
    post "/admin/messaging/announcements", params: { title: "x", body: "y", audience: "all_users", campaignIdentity: "c1" }
    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member submits an announcement" do
    let(:member) { create(:user, roles: ["member"]) }
    let(:member_headers) { authenticate_request_with_bearer!(member) }

    before do
      post "/admin/messaging/announcements",
           params: {
             title: "Invite",
             body: "Book: https://example.com/deeplink/1",
             audience: "user_ids",
             userIds: targets.map(&:id),
             campaignIdentity: "admin/test/1",
             notificationTypeKey: "promotional_announcement",
             executionMode: "sync",
           },
           headers: member_headers
    end

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "accepts an admin announcement for specific user ids" do
    post "/admin/messaging/announcements",
         params: {
           title: "You're invited",
           body: "Book here: https://example.com/deeplink/classes/42",
           audience: "user_ids",
           userIds: targets.map(&:id),
           campaignIdentity: "admin/promo/deeplink-1",
           notificationTypeKey: "promotional_announcement",
           executionMode: "sync",
         },
         headers: headers

    expect(response).to have_http_status(:accepted)
    body = response.parsed_body["data"]
    expect(body["mode"]).to eq("sync")
    expect(body["accepted"]).to eq(2)
    targets.each do |user|
      communication = CommandTower::Messaging::Communication.find_by!(
        user_id: user.id,
        host_event_identity: "admin/promo/deeplink-1/#{user.id}",
      )
      expect(communication.title).to eq("You're invited")
      expect(communication.body).to include("https://example.com/deeplink/classes/42")
      expect(communication.inbox_item).to be_present
    end
  end
end
