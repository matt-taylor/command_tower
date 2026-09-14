# frozen_string_literal: true

# D-CONVERSATION (Rich Messaging Campaign 1): Conversation remains DEFER —
# no columns, kwargs, metadata keys, document fields, or Inbox grouping.
# RM.1–RM.3 added no Conversation code; this is an explicit regression guard
# for that absence rather than relying only on "no code exists."
RSpec.describe "Rich Messaging Conversation defer (D-CONVERSATION)" do
  let(:source_for) do
    lambda { |path| File.read(CommandTower::Engine.root.join(path)) }
  end

  context "Inbox detail response" do
    subject(:payload) do
      CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(
        id: 1, title: "Notice", status: "created", viewed_at: nil,
        created_at: Time.zone.now, updated_at: Time.zone.now,
        body: "Body", metadata: nil, notification_type_key: "example.type",
        content: { schema: "inbox_document_v1", blocks: [] },
      )
    end

    it "never includes a conversation key" do
      expect(payload.keys.map(&:to_s)).not_to include(a_string_matching(/conversation/i))
    end
  end

  context "Inbox document rendering source" do
    it "InboxDocument, InboxDocumentRenderer, and TemplateResolver never reference Conversation" do
      %w[
        app/services/command_tower/messaging/rendering/inbox_document.rb
        app/services/command_tower/messaging/rendering/inbox_document_renderer.rb
        app/services/command_tower/messaging/rendering/template_resolver.rb
      ].each do |path|
        expect(source_for.call(path)).not_to match(/conversation/i)
      end
    end
  end

  context "Inbox service and serializer source" do
    it "Services::Messaging::Inbox and Serializers::Messaging::Inbox never reference Conversation" do
      %w[
        app/services/command_tower/services/messaging/inbox.rb
        app/serializers/command_tower/serializers/messaging/inbox.rb
      ].each do |path|
        expect(source_for.call(path)).not_to match(/conversation/i)
      end
    end
  end

  it "defines no Conversation model" do
    expect(defined?(CommandTower::Messaging::Conversation)).to be_nil
  end
end
