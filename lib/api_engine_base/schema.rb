# frozen_string_literal: true

module ApiEngineBase
  module Schema
    require "json_schematize"
    require "json_schematize/generator"

    ## Generic Error Schemas
    require "api_engine_base/schema/error/base"
    require "api_engine_base/schema/error/invalid_argument_response"

    ## Plain Text Controller
    require "api_engine_base/schema/plain_text/create_user_response"
    require "api_engine_base/schema/plain_text/create_user_request"

    require "api_engine_base/schema/plain_text/email_verify_request"
    require "api_engine_base/schema/plain_text/email_verify_response"

    require "api_engine_base/schema/plain_text/email_verify_send_response"
    require "api_engine_base/schema/plain_text/email_verify_send_request"

    require "api_engine_base/schema/plain_text/login_request"
    require "api_engine_base/schema/plain_text/login_response"

    require "api_engine_base/schema/admin/users"

    require "api_engine_base/schema/user"
    require "api_engine_base/schema/page"
  end
end
