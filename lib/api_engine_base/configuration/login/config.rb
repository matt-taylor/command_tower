# frozen_string_literal: true

require "api_engine_base/configuration/login/strategy/plain_text/config"

module ApiEngineBase
  module Configuration
    module Login
      class Config < ::ApiEngineBase::Configuration::Base
        include ClassComposer::Generator

        add_composer_blocking :plain_text,
          desc: "Login strategy for plain text authentication via User/Password combination",
          composer_class: Strategy::PlainText::Config,
          enable_attr: :enable
      end
    end
  end
end
