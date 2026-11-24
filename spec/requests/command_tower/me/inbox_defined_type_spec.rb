# frozen_string_literal: true

# Inbox reads for a type with a MessageDefinition: catalog selection, `code` redaction while
# impersonating (or when unknown), and `Cache-Control: no-store` on every read route.
RSpec.describe "Me inbox defined type reads", :defined_render, :messaging_inbox, :messaging_notification_types,
               :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:inbox_item) do
    communication = create(
      :messaging_communication,
      user:, notification_type_key: "defined.render", body: "Check in is open",
      conversation_key: "week-5", conversation_title: "Week 5",
      metadata: { "headline" => "Check in is open", "class_name" => "Arms", "door_code" => secret_code },
      metadata_version: 1, slots: { "headline" => "Check in is open" }
    )
    create(:messaging_inbox_item, communication:)
  end

  before do
    stub_const("DefinedRequestSample", Class.new(CommandTower::Messaging::MessageDefinition) do
      metadata_version 1
      fixture :default, metadata: { "headline" => "Check in is open", "class_name" => "Arms", "door_code" => "000000" }
      define_method(:slots) do |metadata:, **|
        { headline: metadata["headline"], subject: "S", push_body: "P", sms_body: "M" }
      end

      def facts(builder, metadata:)
        builder.facts do |f|
          f.key_value { |rows| rows.item "Class", metadata["class_name"] }
          f.code value: metadata["door_code"], label: "Door code", format: :text
        end
      end
    end)
    register_and_seal_notification_types(
      build_notification_type_declaration(key: "defined.render", message: "DefinedRequestSample")
    )
    inbox_item
  end

  %i[show open conversation index].each do |route|
    describe "#{route} route" do
      it "sets Cache-Control no-store" do
        read_inbox(route, headers)
        expect(response.headers["Cache-Control"]).to eq("no-store")
      end

      it "carries no code value while impersonating" do
        read_inbox(route, impersonation_headers.merge("X-UI-Catalog" => "2"))
        expect(response.body).not_to include(secret_code)
      end
    end
  end

  describe "detail metadata while impersonating" do
    let(:communication) { inbox_item.communication }

    context "when the registry is down" do
      before do
        allow(CommandTower::Messaging::NotificationTypes).to receive(:lookup).and_raise(StandardError, "registry down")
      end

      it "withholds metadata of a definition-backed row without consulting the registry" do
        expect(CommandTower::Services::Messaging::Inbox.detail_metadata(communication, impersonating: true)).to be_nil
      end
    end

    context "when reading the row raises" do
      before do
        allow(communication).to receive(:message_definition_backed?).and_raise(StandardError, "boom")
      end

      it "withholds metadata" do
        expect(CommandTower::Services::Messaging::Inbox.detail_metadata(communication, impersonating: nil)).to be_nil
      end
    end

    context "when the row has no definition" do
      before do
        allow(communication).to receive(:message_definition_backed?).and_return(false)
      end

      it "keeps metadata" do
        expect(CommandTower::Services::Messaging::Inbox.detail_metadata(communication, impersonating: true))
          .to eq(communication.metadata)
      end
    end
  end

  %i[show open conversation].each do |route|
    describe "#{route} route content" do
      it "returns a ui_document at catalog 2 with the code for the real recipient" do
        read_inbox(route, headers.merge("X-UI-Catalog" => "2"))
        expect(content_json).to include(secret_code, "ui_document")
      end

      it "returns inbox_document_v1 without the code at catalog 1" do
        read_inbox(route, headers)
        expect(content_json).to include("inbox_document_v1").and(satisfy { |json| json.exclude?(secret_code) })
      end

      it "returns the redaction text at catalog 2 while impersonating" do
        read_inbox(route, impersonation_headers.merge("X-UI-Catalog" => "2"))
        expect(response.body).to include(CommandTower::UI::Redaction::REPLACEMENT_TEXT)
      end
    end
  end
end
