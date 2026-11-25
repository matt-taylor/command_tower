# frozen_string_literal: true

require "command_tower/password_policy/blocklist"
require "command_tower/configuration/login/strategy/plain_text/lockable"
require "command_tower/configuration/login/strategy/plain_text/email_verify"
require "command_tower/configuration/login/strategy/plain_text/password_reset"

module CommandTower
  module Configuration
    module Login
      module Strategy
        module PlainText
          class Config < ::CommandTower::Configuration::Base
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

            add_composer_blocking :password_reset,
              desc: "Enable and change Password Reset for User/Password Login strategy.",
              composer_class: PasswordReset,
              enable_attr: :enabled

            add_composer :password_length_max,
              desc: "Max Length for Password (inclusive)",
              allowed: Integer,
              default: 64

            add_composer :password_length_min,
              desc: "Min Length for Password (inclusive)",
              allowed: Integer,
              default: 8

            add_composer :email_length_max,
              desc: "Max Length for Email (inclusive)",
              allowed: Integer,
              default: 254

            add_composer :email_length_min,
              desc: "Min Length for Email (inclusive)",
              allowed: Integer,
              default: 3

            add_composer :password_blocklist_paths,
              desc: "Files of common passwords to reject (.gz is gunzipped). Defaults to bundled top-100k.",
              allowed: Array,
              default: [CommandTower::PasswordPolicy::Blocklist::DEFAULT_PATH]

            def enable?
              enable
            end
          end
        end
      end
    end
  end
end
