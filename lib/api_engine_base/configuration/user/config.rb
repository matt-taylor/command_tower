# frozen_string_literal: true

require "class_composer"

module ApiEngineBase
  module Configuration
    module User
      class Config
        include ClassComposer::Generator

        ATTRIBUTES_TO_CHANGE = [
          :email,
          :first_name,
          :last_name,
          :last_known_timezone,
          :username,
          :verifier_token,
        ]

        ATTRIBUTES_TO_SHOW = [
          *ATTRIBUTES_TO_CHANGE,
          :id,
          :roles,
          :created_at,
        ]

        ATTRIBUTES_CHANGE_EXECUTE = Proc.new do |key, value|
          ApiEngineBase::UserAttributes::Modify.assign!
        end

        ATTRIBUTES_SHOWN_EXECUTE = Proc.new do |key, value|
          ApiEngineBase::Schema::User.assign!
        end

        add_composer :additional_attributes_for_change,
          desc: "On top of the default attributes to change, this adds additional values for the user to change on their account",
          allowed: Array,
          default: [],
          default_shown: "[]"

        add_composer :default_attributes_for_change,
          desc: "[Not Recommended for change] Default attributes that are allowed to change",
          allowed: Array,
          default: ATTRIBUTES_TO_CHANGE,
          &ATTRIBUTES_CHANGE_EXECUTE

        add_composer :default_attributes,
          desc: "[Not Recommended for change] Default attributes that are shown to the user",
          allowed: Array,
          default_shown: ATTRIBUTES_TO_SHOW,
          dynamic_default: -> (instance) { (ATTRIBUTES_TO_SHOW + instance.additional_attributes_for_change).uniq },
          &ATTRIBUTES_SHOWN_EXECUTE
      end
    end
  end
end
