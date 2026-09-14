# frozen_string_literal: true

module CommandTower
  # Rich Messaging Slice 2.5 — registry of registered Inbox presentation
  # capabilities (semantic keys such as `pickem.make_picks`) mapped to a
  # trusted, host- or CommandTower-owned composer class. See
  # artifacts/visual-improvements/rich-messaging/authority/RICH_MESSAGING_PRESENTATION_AUTHORITY.md
  # Part I and
  # artifacts/visual-improvements/rich-messaging/authority/RICH_MESSAGING_RUBY_INBOX_DEFINITION_DISCOVERY.md §9.
  module InboxPresentations
    class Error < CommandTower::Error; end

    class UnregisteredCapabilityError < Error; end
    class DuplicateCapabilityError < Error; end
    class InvalidKeyError < Error; end
    class InvalidPresentationDefinitionError < Error; end
    class FrozenRegistryError < Error; end
  end
end
