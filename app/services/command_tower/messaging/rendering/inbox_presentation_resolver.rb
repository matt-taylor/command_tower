# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Resolves one presentation block through the inbox presentation registry.
      # Returns the projected block, or nil when the capability is missing,
      # the composer fails, or the composer raises. Does not persist and does
      # not perform network I/O. Callers own the one-presentation budget.
      class InboxPresentationResolver
        def self.resolve(communication:, recipient_id:, block:)
          new(communication:, recipient_id:, block:).resolve
        end

        def initialize(communication:, recipient_id:, block:)
          @communication = communication
          @recipient_id = recipient_id
          @block = block
        end

        def resolve
          definition = CommandTower.config.registry.inbox_presentations.fetch(block[:key])
          raw_data = unwrap(definition.composer_class.constantize.call(communication:, recipient_id:))
          return nil if raw_data.nil?

          {
            type: "presentation",
            key: block[:key],
            variant: block[:variant],
            data: raw_data.to_h.slice(*definition.output_keys),
          }.freeze
        rescue StandardError
          nil
        end

        private

        attr_reader :communication, :recipient_id, :block

        def unwrap(composer_result)
          if composer_result.respond_to?(:success?)
            return nil unless composer_result.success?

            composer_result.data
          else
            composer_result
          end
        end
      end
    end
  end
end
