# frozen_string_literal: true

RSpec.describe "Admin message gallery test send", :messaging_notification_types, :with_rbac_setup, type: :request do
  let(:actor) { create(:user, roles: ["gallery_operator"]) }
  let(:headers) { authenticate_request_with_bearer!(actor) }
  let(:fake_adapter) { CommandTower::Messaging::Execution::Adapters::FakeAdapter.new }
  let(:path) { "/admin/messaging/gallery/class_canceled/test-send" }

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    entities = CommandTower::Authorization::Entity.entities
    CommandTower::Authorization::Role.create_role(
      name: "gallery_operator", description: "Example host role with both gallery grants",
      entities: [entities.fetch("admin_messaging_gallery"), entities.fetch("admin_messaging_gallery_test_send")]
    )
    CommandTower::Authorization::Role.create_role(
      name: "gallery_viewer", description: "Example host role with the preview grant only",
      entities: [entities.fetch("admin_messaging_gallery")]
    )
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "class_canceled", label: "Class canceled", message: "ClassCanceled",
        allowed_channels: %w[email push sms pushover], default_channels: %w[email],
        inbox_available: true,
        default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
      ),
      build_notification_type_declaration(
        key: "push_only", label: "Push only", message: "ClassCanceled",
        allowed_channels: %w[push], default_channels: %w[push], inbox_available: true,
        default_preference_state: { "channels" => { "push" => true }, "inbox" => true }
      ),
      build_notification_type_declaration(key: "plain_type", label: "Plain type")
    )
    allow(CommandTower::Messaging::Execution::SelectAdapter).to receive(:call).and_return(fake_adapter)
  end

  describe "POST /admin/messaging/gallery/:notification_type_key/test-send" do
    it "rejects unauthenticated requests" do
      post path

      expect(response).to have_http_status(:unauthorized)
    end

    context "with the preview grant only" do
      let(:actor) { create(:user, roles: ["gallery_viewer"]) }

      before { post path, headers: }

      it "returns 403 without the test-send grant" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with the grant" do
      let(:sent) { fake_adapter.last_request.rendered }

      before { post path, headers: }

      it "accepts, not cached", :aggregate_failures do
        expect(response).to have_http_status(:accepted)
        expect(response.headers["Cache-Control"]).to eq("no-store")
        expect(response.parsed_body.fetch("data")).to eq("notificationTypeKey" => "class_canceled", "sent" => true)
      end

      it "hands one email to the adapter, addressed to the actor", :aggregate_failures do
        expect(fake_adapter.last_request.channel_key).to eq("email")
        expect(sent.recipient_address).to eq(actor.email)
      end

      it "keeps the preview subject and adds no unsubscribe headers", :aggregate_failures do
        expect(sent.subject).to eq(
          CommandTower::Services::Messaging::Gallery::RenderGalleryPreview
            .call(notification_type_key: "class_canceled").data.dig(:preview, :channels, :email, :subject)
        )
        expect(sent.headers.keys.grep(/list-unsubscribe/i)).to be_empty
      end

      it "puts the Test message line above the compliance footer", :aggregate_failures do
        expect(sent.text_body.index("Test message")).to be < sent.text_body.index("Manage email preferences")
        expect(sent.html_body.index("Test message")).to be < sent.html_body.index("Manage email preferences")
      end

      it "writes no Communication" do
        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end

    context "with the grant, auditing" do
      let(:audit_metadata) { CommandTower::Audit::Event.find_by!(action: "messaging_gallery_test_sent").metadata }

      before { post path, headers: }

      it "audits ids and the type key, never the address", :aggregate_failures do
        expect(audit_metadata).to include("notification_type_key" => "class_canceled", "actor_id" => actor.id)
        expect(audit_metadata.to_json).not_to include(actor.email)
      end
    end

    it "registers the audit event with one-year retention" do
      expect(CommandTower.config.registry.audit.fetch(:messaging_gallery_test_sent).retention).to eq(:one_year)
    end

    context "with an unknown type, a type without a definition or a type without email" do
      it "returns 404 for an unknown type" do
        post "/admin/messaging/gallery/nope/test-send", headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a type without a definition" do
        post "/admin/messaging/gallery/plain_type/test-send", headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 422 for a type that does not allow email and sends nothing", :aggregate_failures do
        post "/admin/messaging/gallery/push_only/test-send", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(fake_adapter.last_request).to be_nil
      end
    end

    # E-07: the request runs as an impersonated session, so the test send is refused (not 418) and
    # nothing is delivered.
    context "when impersonating (E-07)" do
      let(:session) do
        create(:impersonation_session, actor: create(:user, :role_impersonation_operator), target: actor,
                                       idle_expires_at: 2.minutes.from_now, absolute_expires_at: 1.hour.from_now)
      end

      before { post path, headers: authenticate_impersonation_with_bearer!(session.actor, session) }

      it "returns 403 gallery_test_send_impersonating and sends nothing", :aggregate_failures do
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body.fetch("errors").pluck("code")).to eq(["gallery_test_send_impersonating"])
        expect(fake_adapter.last_request).to be_nil
      end
    end

    context "when the actor passes the hourly cap" do
      before do
        6.times { post path, headers: }
      end

      it "returns 429 with retry_after_seconds and sends no sixth email", :aggregate_failures do
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body.fetch("errors").pluck("code")).to eq(["gallery_test_send_rate_limited"])
        expect(response.parsed_body.fetch("errors").first.fetch("details")).to include("retry_after_seconds")
        expect(CommandTower::Messaging::Execution::SelectAdapter).to have_received(:call).exactly(5).times
      end
    end

    context "when Redis fails" do
      before do
        auth_headers = headers
        allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError)
        post path, headers: auth_headers
      end

      it "fails closed and sends nothing", :aggregate_failures do
        expect(response).to have_http_status(:internal_server_error)
        expect(fake_adapter.last_request).to be_nil
      end
    end

    context "when the adapter refuses the message" do
      let(:fake_adapter) do
        CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(
          outcome: :terminal_failure, error_code: "smtp_rejected"
        )
      end

      before { post path, headers: }

      it "returns 502 with the adapter code only", :aggregate_failures do
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body.fetch("errors").pluck("code")).to eq(["gallery_test_send_failed"])
      end
    end
  end
end
