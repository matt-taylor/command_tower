# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class ChannelCatalog
        def self.entries_for(declaration)
          ::CommandTower::Messaging::Channels::DEFINITIONS.filter_map do |definition|
            next if definition.inbox? && !declaration.inbox_available
            next if definition.external? && !declaration.allowed_channels.include?(definition.key)

            {
              key: definition.key,
              label: definition.label,
              description: definition.description,
              order: definition.order,
              glyph_key: definition.glyph_key,
            }.freeze
          end.freeze
        end
      end
    end
  end
end
