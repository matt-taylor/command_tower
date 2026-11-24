# frozen_string_literal: true

# Builds RenderContexts for MessageDefinition classes in specs.
module MessageDefinitionRenderContextHelper
  def context_for(definition, metadata)
    CommandTower::Messaging::Definitions::RenderContext.new(
      notification_type_key: definition.name.underscore, metadata:,
      metadata_version: definition.metadata_version, slots: nil,
      render_zone: definition.default_zone
    )
  end

  def first_context(definition)
    context_for(definition, definition.fixtures.values.first)
  end
end

RSpec.configure do |config|
  config.include MessageDefinitionRenderContextHelper, :message_definition_render_context
end
