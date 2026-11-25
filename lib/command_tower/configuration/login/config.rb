# frozen_string_literal: true

require "command_tower/configuration/login/strategy/plain_text/config"

module CommandTower
  module Configuration
    module Login
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :mail_delivery,
          desc: "How auth emails (password reset) are delivered. :later enqueues an ActiveJob so the request " \
                "never waits on mail; :inline performs the job in the request. Defaults to :later",
          allowed: Symbol,
          default: :later,
          validator: ->(val) { %i[later inline].include?(val) },
          invalid_message: ->(val) { "Provided #{val.inspect}. Value must be :later or :inline" }

        add_composer_blocking :plain_text,
          desc: "Login strategy for plain text authentication via User/Password combination",
          composer_class: Strategy::PlainText::Config,
          enable_attr: :enable
      end
    end
  end
end
