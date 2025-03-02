# frozen_string_literal: true

require "command_tower/configuration/login/strategy/plain_text/config"

module CommandTower
  module Configuration
    module Login
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer_blocking :plain_text,
          desc: "Login strategy for plain text authentication via User/Password combination",
          composer_class: Strategy::PlainText::Config,
          enable_attr: :enable
      end
    end
  end
end
