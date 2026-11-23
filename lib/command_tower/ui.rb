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
