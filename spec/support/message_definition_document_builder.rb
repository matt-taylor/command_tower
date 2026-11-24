# frozen_string_literal: true

# Helpers for DocumentBuilder specs. Expects the including group to define `metadata` and `definition`.
module MessageDefinitionDocumentBuilderHelper
  def context_for(metadata: self.metadata, slots: nil, render_zone: "America/New_York")
    CommandTower::Messaging::Definitions::RenderContext.new(
      notification_type_key: "class_canceled", metadata:, metadata_version: 1, slots:, render_zone:
    )
  end

  def inbox_root(context: context_for, definition: self.definition)
    described_class.inbox(definition:, context:).as_json["root"]
  end

  # inbox_root for a context built from the given context_for arguments.
  def inbox_root_for(**context_args)
    inbox_root(context: context_for(**context_args))
  end

  def child_types(root)
    root["children"].pluck("type")
  end
end

RSpec.configure do |config|
  config.include MessageDefinitionDocumentBuilderHelper, :message_definition_document_builder
end
