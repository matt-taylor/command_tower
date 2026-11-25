# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # A notice a host workflow pushes to one user (for example "class canceled") through
    # `Deliver`. Adds the composer macro.
    class Delivery < Notice
      COMPOSERS = %i[message].freeze

      class << self
        def composer(value = nil)
          return inherited_setting(:@composer) if value.nil?

          unless COMPOSERS.include?(value)
            raise ArgumentError, "composer must be one of #{COMPOSERS.inspect} (got #{value.inspect})"
          end

          @composer = value
        end
      end

      # Default for a linked delivery (`composer :message`): shown while the user has not viewed the
      # linked inbox item. False when it is viewed (true) or unavailable (nil: missing, deleted,
      # foreign or not inbox-backed). Hosts may override and call `super`. An unlinked delivery
      # has no default meaning, so it is shown; the catalog requires it to override `show?`.
      def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
        return true unless self.class.composer == :message
        return false if notice&.communication_id.nil?

        unviewed?(user, notice.communication_id)
      end

      private

      def unviewed?(user, communication_id)
        request = CommandTower::Messaging::Contract::Requests::ViewedForCommunication.build(
          communication_id:, recipient_id: user.id
        )
        CommandTower::Messaging::Contract::Inbox.viewed_for_communication?(request) == false
      end
    end
  end
end
