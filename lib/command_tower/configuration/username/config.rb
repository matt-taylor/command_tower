# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/username/check"

module CommandTower::Configuration
  module Username
    class Config
      include ClassComposer::Generator

      DEFAULT_MAX_LENGTH = 32
      DEFAULT_MIN_LENGTH = 4

      add_composer_blocking :realtime_username_check,
        desc: "Adds components to check if the username is available in real time",
        composer_class: Check,
        enable_attr: :enable

      add_composer :username_length_min,
        desc: "Min Length for Username",
        allowed: Integer,
        default: DEFAULT_MIN_LENGTH

      add_composer :username_length_max,
        desc: "Max Length for Username",
        allowed: Integer,
        default: DEFAULT_MAX_LENGTH

      add_composer :username_regex,
        desc: "Regex for username.",
        allowed: Regexp,
        default: /\A\w{#{DEFAULT_MIN_LENGTH},#{DEFAULT_MAX_LENGTH}}\z/,
        default_shown: "Regexp.new(\"/\A\w{#{DEFAULT_MIN_LENGTH},#{DEFAULT_MAX_LENGTH}}\z/\")"

      add_composer :username_failure_message,
        desc: "Max Length for Username",
        allowed: String,
        default: "Username length must be between #{DEFAULT_MIN_LENGTH} and #{DEFAULT_MAX_LENGTH}. Must contain only letters and/or numbers"
    end
  end
end
