# frozen_string_literal: true

# Helpers for specs that render MessageDefinition-backed types. Expects the including group to
# define `communication` (and, for the inbox read helpers, `user`, `inbox_item`).
module MessagingDefinedRenderHelper
  SECRET_CODE = "SECRET-481516"

  def secret_code
    SECRET_CODE
  end

  # InboxDocumentRenderer.render with the catalog and impersonation inputs.
  def render(ui_catalog: 1, impersonating: false, communication: self.communication)
    described_class.render(communication:, recipient_id: 4242, ui_catalog:, impersonating:)
  end

  def register_definition(definition)
    stub_const("DefinedRenderSample", definition)
    register_and_seal_notification_types(
      build_notification_type_declaration(key: "defined.render", message: "DefinedRenderSample")
    )
  end

  def definition_class(&)
    Class.new(CommandTower::Messaging::MessageDefinition) do
      metadata_version 1
      fixture :default, metadata: { "headline" => "Check in is open", "class_name" => "Arms", "door_code" => "000000" }
      define_method(:slots) do |metadata:, **|
        { headline: metadata["headline"], subject: "Subject", push_body: "Push", sms_body: "SMS" }
      end
      class_eval(&)
    end
  end

  # ChannelRenderer.render for one channel of `communication`.
  def render_channel(channel_key, address)
    described_class.render(communication:, channel_key:, recipient_address: address)
  end

  def impersonation_headers
    operator = create(:user, :role_impersonation_operator)
    session = create(
      :impersonation_session,
      actor: operator, target: user, idle_expires_at: 2.minutes.from_now, absolute_expires_at: 1.hour.from_now
    )
    authenticate_impersonation_with_bearer!(operator, session)
  end

  def read_inbox(route, request_headers)
    case route
    when :show then get "/me/inbox/#{inbox_item.id}", headers: request_headers
    when :open then post "/me/inbox/#{inbox_item.id}/open", headers: request_headers
    when :conversation
      get "/me/inbox/conversation", params: { key: "week-5", scope: "inbox" }, headers: request_headers
    when :index then get "/me/inbox", headers: request_headers
    end
  end

  # Every `content` document in the response (the raw `metadata` of the recipient's own read is not content).
  def content_json
    data = response.parsed_body.fetch("data")
    (data.key?("messages") ? data["messages"] : [data]).pluck("content").to_json
  end
end

RSpec.configure do |config|
  config.include MessagingDefinedRenderHelper, :defined_render
end
