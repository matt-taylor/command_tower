# frozen_string_literal: true

module CommandTower
  module Schema
    require "json_schematize"
    require "json_schematize/generator"

    ## Generic Error Schemas
    require "command_tower/schema/error/base"
    require "command_tower/schema/error/email_validation_required"
    require "command_tower/schema/error/invalid_argument_response"

    require "command_tower/schema/shared/user"
  end
end
