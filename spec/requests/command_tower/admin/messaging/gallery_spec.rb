# frozen_string_literal: true

RSpec.describe "Admin message gallery", :messaging_notification_types, :with_rbac_setup, type: :request do
  let(:owner_headers) { authenticate_request_with_bearer!(create(:user, :role_owner)) }
  let(:data) { response.parsed_body.fetch("data") }
  let(:checks) { data["checks"] }
  let(:channels) { data["channels"] }

  # RBAC fails closed for a controller no role maps, owner included. This example host role stands
  # in for a host that grants the gallery (the dummy host's `messaging_gallery_operator` does too).
  before do
    entities = CommandTower::Authorization::Entity.entities
    CommandTower::Authorization::Role.create_role(
      name: "gallery_operator", description: "Example host role with both gallery grants",
      entities: [entities.fetch("admin_messaging_gallery"), entities.fetch("admin_messaging_gallery_test_send")]
    )
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "class_canceled", label: "Class canceled", message: "ClassCanceled",
        allowed_channels: %w[email push sms pushover], default_channels: %w[email],
        inbox_available: true,
        default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
      ),
      build_notification_type_declaration(
        key: "check_in_ready", label: "Check in ready", message: "CheckInReady",
        allowed_channels: %w[email], default_channels: %w[email], inbox_available: false,
        default_preference_state: { "channels" => { "email" => true }, "inbox" => false }
      ),
      build_notification_type_declaration(key: "plain_type", label: "Plain type")
    )
  end

  describe "authorization" do
    it "rejects unauthenticated requests" do
      get "/admin/messaging/gallery"

      expect(response).to have_http_status(:unauthorized)
    end

    context "with a host role holding both gallery grants" do
      let(:headers) { authenticate_request_with_bearer!(create(:user, roles: ["gallery_operator"])) }

      before do
        get "/admin/messaging/gallery", headers: headers
        get "/admin/messaging/gallery/class_canceled", headers: headers
      end

      it "allows index and show" do
        expect(response).to have_http_status(:ok)
      end
    end

    %w[member admin].each do |role|
      context "with the #{role} role, which does not hold the grant" do
        let(:headers) { authenticate_request_with_bearer!(create(:user, roles: [role])) }

        it "returns 403 on index" do
          get "/admin/messaging/gallery", headers: headers

          expect(response).to have_http_status(:forbidden)
        end

        it "returns 403 on show" do
          get "/admin/messaging/gallery/class_canceled", headers: headers

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe "GET /admin/messaging/gallery" do
    before { get "/admin/messaging/gallery", headers: owner_headers }

    it "lists only the defined types" do
      expect(data.pluck("notificationTypeKey")).to eq(%w[class_canceled check_in_ready])
    end

    it "describes each type with its fixtures" do
      expect(data.first).to include("label" => "Class canceled", "definition" => "ClassCanceled",
                                    "promotional" => false, "allowedChannels" => %w[email push sms pushover],
                                    "fixtures" => [{ "name" => "default", "metadataVersion" => 1 },
                                                   { "name" => "other_zone", "metadataVersion" => 1 }])
    end

    it "is not cached" do
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  describe "GET /admin/messaging/gallery/:notification_type_key" do
    context "with a type that allows every channel" do
      before { get "/admin/messaging/gallery/class_canceled", headers: owner_headers }

      it "is not cached" do
        expect(response.headers["Cache-Control"]).to eq("no-store")
      end

      it "names the type, fixture and render zone" do
        expect(data).to include(
          "notificationTypeKey" => "class_canceled", "fixture" => "default", "metadataVersion" => 1,
          "renderZone" => "America/Los_Angeles"
        )
      end

      it "renders every channel" do
        expect(channels.values).to all(be_present)
      end

      it "carries the inbox document and a non-fallback email", :aggregate_failures do
        expect(channels["inbox"]["content"]["schema"]).to be_present
        expect(channels["email"]).to include("usedFallback" => false)
      end

      it "keeps tokens out of the email" do
        expect(channels["email"]["html"]).not_to include("token=")
      end

      it "renders the fact block for the app and for email", :aggregate_failures do
        expect(data.dig("facts", "app")).to be_present
        expect(data.dig("facts", "emailHtml")).to include("<table")
      end

      it "passes every check" do
        expect(checks.pluck("passed")).to all(be(true))
      end

      it "runs the fact, code and time checks" do
        expect(checks.pluck("check").uniq).to include(
          "required_fact", "fact_block_once", "no_code_in_slots_or_body", "no_time_in_headline"
        )
      end
    end

    context "with a zone and a second fixture" do
      before do
        get "/admin/messaging/gallery/class_canceled", params: { fixture: "other_zone", zone: "America/New_York" },
                                                       headers: owner_headers
      end

      it "uses the zone as the render zone" do
        expect(data).to include("fixture" => "other_zone", "renderZone" => "America/New_York")
      end
    end

    context "with a type that does not allow the inbox or push" do
      before { get "/admin/messaging/gallery/check_in_ready", headers: owner_headers }

      it "sets those channels to null, the inbox included" do
        expect(channels).to include("push" => nil, "sms" => nil, "pushover" => nil, "inbox" => nil)
      end

      it "shows the email fallback" do
        expect(channels["email"]).to include("usedFallback" => true)
      end

      it "fails the code check when the email composer carries a code", :aggregate_failures do
        expect(checks.find { |check| check["check"] == "no_code_in_slots_or_body" }["passed"]).to be(false)
        expect(response.body).not_to include("token=")
      end
    end

    describe "not found" do
      it "returns 404 for an unknown type" do
        get "/admin/messaging/gallery/nope", headers: owner_headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a type with no definition" do
        get "/admin/messaging/gallery/plain_type", headers: owner_headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for an undeclared fixture" do
        get "/admin/messaging/gallery/class_canceled", params: { fixture: "missing" }, headers: owner_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 422 for an invalid zone" do
      get "/admin/messaging/gallery/class_canceled", params: { zone: "Mars/Olympus" }, headers: owner_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    context "when a composer raises" do
      before do
        stub_const("ClassCanceled", Class.new(ClassCanceled) do
          def inbox(*, **) = raise("secret-value-do-not-leak")
        end)
        get "/admin/messaging/gallery/class_canceled", headers: owner_headers
      end

      it "fails with 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "names only the channel and error class", :aggregate_failures do
        expect(response.body).to include("channel: inbox", "RuntimeError")
        expect(response.body).not_to include("secret-value")
      end
    end

    context "when counting the SQL a preview runs" do
      let(:statements) { [] }

      around do |example|
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          statements << payload[:sql]
        end
        example.run
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      before do
        headers = owner_headers
        statements.clear
        get "/admin/messaging/gallery", headers: headers
        get "/admin/messaging/gallery/class_canceled", headers: headers
      end

      it "reads no Communication", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(statements.grep(/communications/i)).to be_empty
      end
    end
  end
end
