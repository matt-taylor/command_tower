# frozen_string_literal: true

require "api_engine_base/configuration/login/strategy/plain_text/lockable"
require "api_engine_base/configuration/login/strategy/plain_text/email_verify"

module ApiEngineBase
  module Configuration
    module Login
      module Strategy
        module PlainText
          class Config < ::ApiEngineBase::Configuration::Base
            include ClassComposer::Generator

            add_composer :enable,
              desc: "Login Strategy for User/Password. By default, this is enabled",
              allowed: [FalseClass, TrueClass],
              default: true

            add_composer_blocking :lockable,
              desc: "Enable and change Lockable for User/Password Login strategy.",
              composer_class: Locakable,
              enable_attr: :enable

            add_composer_blocking :email_verify,
              desc: "Enable and change Email Verification for User/Password Login strategy.",
              composer_class: EmailVerify,
              enable_attr: :enable

            add_composer :password_length_max,
              desc: "Max Length for Password",
              allowed: Integer,
              default: 64

            add_composer :password_length_min,
              desc: "Min Length for Password",
              allowed: Integer,
              default: 8

            add_composer :email_length_max,
              desc: "Max Length for Email",
              allowed: Integer,
              default: 64

            add_composer :email_length_min,
              desc: "Min Length for Email",
              allowed: Integer,
              default: 8

            def enable?
              enable
            end
          end
        end
      end
    end
  end
end
