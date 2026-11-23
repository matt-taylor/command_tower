# frozen_string_literal: true

module CommandTower
  module UI
    # Document size limits. Mirrored by the shared fixture
    # spec/fixtures/ui/wire_hardening.json (design section 8.1) so the frontend
    # normalizer enforces the same numbers.
    module Limits
      MAX_NODES = 200
      MAX_DEPTH = 8
      MAX_BYTES = 64 * 1024
      MAX_STRING_LENGTH = 2_000
      MAX_TEXT_FALLBACK_LENGTH = 8_000
      MAX_SPANS = 50
      MAX_KEY_VALUE_ITEMS = 50
      MAX_FACTS_NODES = 100
    end
  end
end
