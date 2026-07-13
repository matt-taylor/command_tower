# frozen_string_literal: true

module CommandTower
  module Schema
    require "json_schematize"
    require "json_schematize/generator"

    ## Generic Error Schemas
    require "command_tower/schema/error/base"
    require "command_tower/schema/error/email_validation_required"
    require "command_tower/schema/error/invalid_argument_response"

    ## Auth Controller
    require "command_tower/schema/auth/plain_text/login/request"
    require "command_tower/schema/auth/plain_text/login/response"
    require "command_tower/schema/auth/plain_text/login_identifier_valid/request"
    require "command_tower/schema/auth/plain_text/login_identifier_valid/response"
    require "command_tower/schema/auth/plain_text/create_user/request"
    require "command_tower/schema/auth/plain_text/create_user/response"
    require "command_tower/schema/auth/plain_text/email_verify/request"
    require "command_tower/schema/auth/plain_text/email_verify/response"
    require "command_tower/schema/auth/plain_text/email_verify/send_request"
    require "command_tower/schema/auth/plain_text/email_verify/send_response"
    require "command_tower/schema/auth/plain_text/password_forgot"
    require "command_tower/schema/auth/plain_text/password_forgot/send/request"
    require "command_tower/schema/auth/plain_text/password_forgot/send/response"
    require "command_tower/schema/auth/plain_text/password_forgot/validate/request"
    require "command_tower/schema/auth/plain_text/password_forgot/validate/response"
    require "command_tower/schema/auth/plain_text/password_forgot/reset/request"
    require "command_tower/schema/auth/plain_text/password_forgot/reset/response"
    require "command_tower/schema/auth/plain_text/change_password"
    require "command_tower/schema/auth/plain_text/change_password/request"
    require "command_tower/schema/auth/plain_text/change_password/response"
    require "command_tower/schema/auth/logout/response"

    require "command_tower/schema/shared/admin/users"

    require "command_tower/schema/shared/user"

    require "command_tower/schema/user/show/request"
    require "command_tower/schema/user/show/response"
    require "command_tower/schema/user/modify/request"
    require "command_tower/schema/user/modify/response"

    require "command_tower/schema/shared/page"
    require "command_tower/schema/shared/pagination"

    require "command_tower/schema/shared/inbox/metadata"
    require "command_tower/schema/shared/inbox/message_blast_metadata"
    require "command_tower/schema/shared/inbox/modified"

    require "command_tower/schema/admin/show/request"
    require "command_tower/schema/admin/show/response"
    require "command_tower/schema/admin/modify/request"
    require "command_tower/schema/admin/modify/response"
    require "command_tower/schema/admin/modify_role/request"
    require "command_tower/schema/admin/modify_role/response"

    require "command_tower/schema/inbox/messages/metadata/request"
    require "command_tower/schema/inbox/messages/metadata/response"
    require "command_tower/schema/inbox/messages/message/request"
    require "command_tower/schema/inbox/messages/message/response"
    require "command_tower/schema/inbox/messages/ack/request"
    require "command_tower/schema/inbox/messages/ack/response"
    require "command_tower/schema/inbox/messages/delete/request"
    require "command_tower/schema/inbox/messages/delete/response"
    require "command_tower/schema/inbox/messages/delete_by_id/request"
    require "command_tower/schema/inbox/messages/delete_by_id/response"
    require "command_tower/schema/inbox/blast/metadata/request"
    require "command_tower/schema/inbox/blast/metadata/response"
    require "command_tower/schema/inbox/blast/create/request"
    require "command_tower/schema/inbox/blast/create/response"
    require "command_tower/schema/inbox/blast/show/request"
    require "command_tower/schema/inbox/blast/show/response"
    require "command_tower/schema/inbox/blast/modify/request"
    require "command_tower/schema/inbox/blast/modify/response"
    require "command_tower/schema/inbox/blast/delete/request"
    require "command_tower/schema/inbox/blast/delete/response"
  end
end
