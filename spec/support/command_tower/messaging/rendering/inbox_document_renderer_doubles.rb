# frozen_string_literal: true

# Named spec-support doubles for `InboxDocumentRendererSpec` (Rich Messaging
# Slice 2.5 revision). Real, named constants are required — not anonymous
# classes defined inside example bodies (testing.mdc) — because
# `InboxDocumentRenderer` resolves both notification-type Inbox document
# composers and registered presentation composers via `.constantize` on a
# String class name, exactly as production registrations do.
module CommandTower
  module Messaging
    module Rendering
      module InboxDocumentRendererSpecDoubles
        # A valid pure-Ruby Inbox document composer (`.call(communication:) ->
        # InboxDocument`), mirroring the real shape of e.g.
        # `Services::Competitive::Messaging::InboxDocuments::IncompleteWager`.
        class ValidTypeComposer
          def self.call(communication:)
            InboxDocument.compose { |doc| doc.paragraph "Composed narrative" }
          end
        end

        # Same as ValidTypeComposer, plus one presentation node.
        class TypeComposerWithPresentation
          def self.call(communication:)
            InboxDocument.compose do |doc|
              doc.paragraph "Composed narrative"
              doc.presentation "rich_messaging_proof.make_picks", variant: :compact
            end
          end
        end

        # Emits two presentation nodes in one document — used to prove the
        # one-attempt cap is consumed on the first attempt regardless of
        # outcome, not on the first success.
        class TypeComposerWithTwoPresentations
          def self.call(communication:)
            InboxDocument.compose do |doc|
              doc.presentation "rich_messaging_proof.unregistered"
              doc.presentation "rich_messaging_proof.make_picks"
            end
          end
        end

        class RaisingTypeComposer
          def self.call(communication:)
            raise StandardError, "boom from type composer double"
          end
        end

        # Returns something other than an InboxDocument — must be treated as
        # invalid, not merely "whatever this Hash happens to contain".
        class InvalidReturnTypeComposer
          def self.call(communication:)
            { schema: "not_inbox_document_v1", blocks: [] }
          end
        end

        # A registered presentation composer double
        # (`.call(communication:, recipient_id:) -> Hash`).
        class PresentationComposerDouble
          def self.call(communication:, recipient_id:)
            { example: "data" }
          end
        end

        class RaisingPresentationComposerDouble
          def self.call(communication:, recipient_id:)
            raise StandardError, "boom from presentation composer double"
          end
        end

        # Returns extra keys beyond its intended output — proves the
        # renderer's `output_keys` projection drops undeclared keys even for
        # a plain Hash-returning (non-`ApplicationService`) composer, not
        # just declared `ApplicationService` inputs.
        class ExtraKeysPresentationComposerDouble
          def self.call(communication:, recipient_id:)
            { example: "data", incidental: "leftover_state" }
          end
        end

        # Simulates a `CommandTower::Services::ApplicationService`-shaped
        # presentation composer (like the real
        # `Services::Competitive::Presentations::MakePicks`) — `.call`
        # returns a `ServiceResult`-duck-typed object (`success?`/`data`)
        # rather than a plain Hash directly.
        FakeServiceResult = Struct.new(:success, :data) do
          def success?
            success
          end
        end

        class SucceedingApplicationServiceStylePresentationComposerDouble
          def self.call(communication:, recipient_id:)
            FakeServiceResult.new(true, { example: "service_result_data" })
          end
        end

        class FailingApplicationServiceStylePresentationComposerDouble
          def self.call(communication:, recipient_id:)
            FakeServiceResult.new(false, {})
          end
        end

        # A *real* `CommandTower::Services::ApplicationService` subclass
        # (not the `FakeServiceResult` duck-type struct above) — its `.data`
        # legitimately contains both its declared inputs (`communication`,
        # `recipient_id`) AND its intentional output (`example`), exactly
        # like the real `Services::Competitive::Presentations::MakePicks`.
        # Used to prove the renderer's `output_keys` projection excludes
        # declared inputs from the wire even though they are real keys on
        # the underlying `ServiceResult`.
        class RealApplicationServicePresentationComposerDouble < CommandTower::Services::ApplicationService
          validate :communication, required: true
          validate :recipient_id, required: true

          def call
            context.example = "real_output"
          end
        end
      end
    end
  end
end
