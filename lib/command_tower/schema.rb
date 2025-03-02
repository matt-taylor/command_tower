# frozen_string_literal: true

module CommandTower
  module Schema
    require "json_schematize"
    require "json_schematize/generator"

    ## Generic Error Schemas
    require "command_tower/schema/error/base"
    require "command_tower/schema/error/invalid_argument_response"

    ## Plain Text Controller
    require "command_tower/schema/plain_text/create_user_response"
    require "command_tower/schema/plain_text/create_user_request"

    require "command_tower/schema/plain_text/email_verify_request"
    require "command_tower/schema/plain_text/email_verify_response"

    require "command_tower/schema/plain_text/email_verify_send_response"
    require "command_tower/schema/plain_text/email_verify_send_request"

    require "command_tower/schema/plain_text/login_request"
    require "command_tower/schema/plain_text/login_response"

    require "command_tower/schema/admin/users"

    require "command_tower/schema/user"
    require "command_tower/schema/page"

    require "command_tower/schema/inbox/metadata"
    require "command_tower/schema/inbox/message_entity"
    require "command_tower/schema/inbox/modified"
    require "command_tower/schema/inbox/blast_response"
    require "command_tower/schema/inbox/blast_request"
    require "command_tower/schema/inbox/message_blast_entity"
    require "command_tower/schema/inbox/message_blast_metadata"
  end
end
