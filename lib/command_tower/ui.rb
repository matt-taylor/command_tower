# frozen_string_literal: true

require "command_tower/error"

module CommandTower
  # Server-driven UI documents: schema, tokens and validation. Pure Ruby; no DB,
  # no Messaging. Authoring reference lives in docs/ui.md (added with the docs task).
  module UI
    CATALOG = 2
    SCHEMA = "ui_document"

    # `details` is an array of { path:, code: } hashes. Paths and codes only,
    # never values (design section 8).
    class InvalidDocumentError < CommandTower::Error
      attr_reader :details

      def initialize(message = nil, details: [])
        super(message)
        @details = details.freeze
      end
    end

    class InvalidTokenError < CommandTower::Error; end
    class InvalidFragmentError < CommandTower::Error; end

    # Builds a Document with the Builder DSL. The block must add exactly one
    # root node. The result is not validated: call `validate!` (Composer does).
    def self.document(text_fallback: nil)
      builder = Builder.new
      yield builder
      roots = builder.roots
      unless roots.one?
        code = roots.empty? ? "root_required" : "multiple_roots"
        raise InvalidDocumentError.new("Invalid UI document: root:#{code}", details: [{ path: "root", code: }])
      end

      Document.new(root: roots.first, text_fallback:)
    end
  end
end

require "command_tower/ui/hostname"
require "command_tower/ui/tokens"
require "command_tower/ui/zone_abbreviation"
require "command_tower/ui/time_formatter"
require "command_tower/ui/catalog"
require "command_tower/ui/limits"
require "command_tower/ui/hardening"
require "command_tower/ui/nodes/base"
require "command_tower/ui/nodes/action"
require "command_tower/ui/nodes/span"
require "command_tower/ui/nodes/stack"
require "command_tower/ui/nodes/card"
require "command_tower/ui/nodes/divider"
require "command_tower/ui/nodes/text"
require "command_tower/ui/nodes/instant"
require "command_tower/ui/nodes/key_value"
require "command_tower/ui/nodes/badge"
require "command_tower/ui/nodes/button"
require "command_tower/ui/nodes/image"
require "command_tower/ui/nodes/banner"
require "command_tower/ui/nodes/avatar"
require "command_tower/ui/nodes/stat_tile"
require "command_tower/ui/nodes/code"
require "command_tower/ui/nodes/component"
require "command_tower/ui/nodes/facts"
require "command_tower/ui/document"
require "command_tower/ui/builder"
require "command_tower/ui/text_derivation"
require "command_tower/ui/fragment"
require "command_tower/ui/composer"
require "command_tower/ui/fragments/header"
require "command_tower/ui/fragments/fact_row"
require "command_tower/ui/fragments/cta_group"
require "command_tower/ui/fragments/notice_frame"
require "command_tower/ui/fragments/facts"
require "command_tower/ui/email/styles"
require "command_tower/ui/email/layout"
require "command_tower/ui/email/renderer"
